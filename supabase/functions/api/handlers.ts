import { type AuditAction, recordAudit } from "./audit.ts";
import { type Member } from "./auth.ts";
import { Buffer, SessionMeta } from "./buffer.ts";
import { json } from "./cors.ts";
import { db } from "./db.ts";
import {
  cleanString,
  optionalString,
  validLatitude,
  validLongitude,
  validShortCode,
} from "./validation.ts";

function generateId(): string {
  return `sess_${Date.now().toString(36)}_${crypto.randomUUID().slice(0, 8)}`;
}

function generateCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no ambiguous chars
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

/// A preceptor controls only their own session; a master may manage any.
function ownsSession(meta: SessionMeta, member: Member): boolean {
  return meta.preceptorId === member.heartfulnessId || member.role === "master";
}

/// Append an audit row, best-effort: a failure here must never break the user's
/// action, so we log it and move on rather than throw.
async function audit(
  member: Member,
  action: AuditAction,
  sessionId?: string,
  detail?: Record<string, unknown>,
): Promise<void> {
  const err = await recordAudit(db(), {
    actorHeartfulnessId: member.heartfulnessId,
    action,
    sessionId,
    detail,
  });
  if (err) {
    console.error(
      JSON.stringify({
        level: "error",
        msg: "audit_failed",
        action,
        error: err,
      }),
    );
  }
}

/// Snake_case DTO matching the Flutter MeditationSession.fromJson contract.
/// Carries only the attendee *count*, never the id list: clients don't need the
/// identities, and shipping a growing 70k-id array on every attend would be
/// O(n²). The full list is materialized only once, at the flush.
function sessionDto(meta: SessionMeta, attendeeCount: number) {
  return {
    id: meta.id,
    preceptor_id: meta.preceptorId,
    center_id: meta.centerId,
    latitude: meta.latitude,
    longitude: meta.longitude,
    start_attendance_at: meta.startAttendanceAt,
    meditation_start_at: meta.meditationStartAt,
    meditation_end_at: meta.meditationEndAt,
    status: meta.status,
    attendee_count: attendeeCount,
    short_code: meta.shortCode,
  };
}

export async function startSession(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<Response> {
  if (!validLatitude(body.latitude) || !validLongitude(body.longitude)) {
    return json({ error: "valid latitude and longitude required" }, 400);
  }
  const centerId = optionalString(body.centerId, 64);
  if (centerId === null) return json({ error: "invalid centerId" }, 400);

  const meta: SessionMeta = {
    id: generateId(),
    preceptorId: member.heartfulnessId, // from the verified token, not the body
    centerId: centerId ?? null,
    latitude: body.latitude,
    longitude: body.longitude,
    startAttendanceAt: new Date().toISOString(),
    meditationStartAt: null,
    meditationEndAt: null,
    status: "collecting",
    shortCode: generateCode(),
    frozen: false,
  };
  await buffer.createSession(meta);
  await audit(member, "session_start", meta.id);
  return json(sessionDto(meta, 0));
}

export async function attend(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<Response> {
  const heartfulnessId = member.heartfulnessId; // from the verified token

  // Code / QR fallback path.
  if (body.code != null) {
    const code = validShortCode(body.code);
    if (!code) return json({ error: "invalid code" }, 400);
    const id = await buffer.resolveCode(code);
    const meta = id ? await buffer.getMeta(id) : null;
    if (!meta || meta.frozen || meta.status !== "collecting") {
      return json({ outcome: "notFound" });
    }
    return await joinAndRespond(buffer, meta, heartfulnessId);
  }

  // GPS path.
  if (!validLatitude(body.latitude) || !validLongitude(body.longitude)) {
    return json({ error: "valid latitude/longitude or code required" }, 400);
  }
  const nearby = await buffer.findNearby(body.latitude, body.longitude);
  if (nearby.length === 0) return json({ outcome: "notFound" });
  if (nearby.length > 1) {
    const candidates = await Promise.all(
      nearby.map(async (m) => sessionDto(m, await buffer.count(m.id))),
    );
    return json({ outcome: "ambiguous", candidates });
  }
  return await joinAndRespond(buffer, nearby[0], heartfulnessId);
}

async function joinAndRespond(
  buffer: Buffer,
  meta: SessionMeta,
  heartfulnessId: string,
): Promise<Response> {
  const added = await buffer.addAttendee(meta.id, heartfulnessId);
  // SCARD, not SMEMBERS: the client only needs the running count.
  const count = await buffer.count(meta.id);
  return json({
    outcome: added ? "joined" : "alreadyJoined",
    session: sessionDto(meta, count),
  });
}

/// Fetch the session and confirm the caller owns it, or return an error
/// Response. Returns the live meta on success.
async function ownedSession(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<SessionMeta | Response> {
  const sessionId = cleanString(body.sessionId, 128);
  if (!sessionId) return json({ error: "sessionId required" }, 400);
  const meta = await buffer.getMeta(sessionId);
  if (!meta) return json({ error: "session not active" }, 404);
  if (!ownsSession(meta, member)) {
    return json({ error: "not your session" }, 403);
  }
  return meta;
}

export async function endAttendance(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<Response> {
  const meta = await ownedSession(buffer, body, member);
  if (meta instanceof Response) return meta;
  const updated: SessionMeta = { ...meta, frozen: true };
  await buffer.putMeta(updated);
  await audit(member, "end_attendance", updated.id);
  return json(sessionDto(updated, await buffer.count(updated.id)));
}

export async function meditationStart(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<Response> {
  const meta = await ownedSession(buffer, body, member);
  if (meta instanceof Response) return meta;
  const updated: SessionMeta = {
    ...meta,
    status: "meditating",
    meditationStartAt: new Date().toISOString(),
  };
  await buffer.putMeta(updated);
  await audit(member, "meditation_start", updated.id);
  return json(sessionDto(updated, await buffer.count(updated.id)));
}

/// The single flush: finalize, write ONE Postgres row, evict from the buffer.
export async function meditationStop(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<Response> {
  const owned = await ownedSession(buffer, body, member);
  if (owned instanceof Response) return owned;
  // The one place the full attendee set is materialized: the single flush that
  // writes it to Postgres. Everywhere else uses SCARD (count only).
  const attendees = await buffer.attendees(owned.id);
  const finalized: SessionMeta = {
    ...owned,
    status: "ended",
    meditationEndAt: new Date().toISOString(),
  };

  const { error } = await db().from("meditation_sessions").insert({
    id: finalized.id,
    preceptor_id: finalized.preceptorId,
    center_id: finalized.centerId,
    latitude: finalized.latitude,
    longitude: finalized.longitude,
    start_attendance_at: finalized.startAttendanceAt,
    meditation_start_at: finalized.meditationStartAt,
    meditation_end_at: finalized.meditationEndAt,
    status: finalized.status,
    attendee_ids: attendees,
    attendee_count: attendees.length,
    short_code: finalized.shortCode,
  });
  if (error) return json({ error: error.message }, 500);

  await buffer.evict(finalized);
  await audit(member, "meditation_stop", finalized.id, {
    attendee_count: attendees.length,
  });
  return json(sessionDto(finalized, attendees.length));
}

/// Delete the caller's *app login only*: the Supabase Auth (GoTrue) user, keyed
/// by the verified `sub` claim. The member's org record and historical
/// attendance are org-owned data and are deliberately left intact (decided with
/// the product owner; see docs/privacy.md retention). Satisfies the app stores'
/// in-app account-deletion requirement. Best-effort audit, keyed off the member.
export async function deleteAccount(
  authUserId: string,
  member: Member,
): Promise<Response> {
  const { error } = await db().auth.admin.deleteUser(authUserId);
  if (error) return json({ error: error.message }, 500);
  await audit(member, "account_delete", undefined, {
    auth_user_id: authUserId,
  });
  return json({ deleted: true });
}

export async function getSession(buffer: Buffer, body: any): Promise<Response> {
  const id = cleanString(body.sessionId, 128);
  if (!id) return json({ error: "sessionId required" }, 400);
  const meta = await buffer.getMeta(id);
  if (meta) {
    return json(sessionDto(meta, await buffer.count(id)));
  }
  // Finalized -> read the row. Select the count column explicitly, never the
  // attendee_ids array (which can be 70k ids and isn't needed by any client).
  const { data, error } = await db()
    .from("meditation_sessions")
    .select(
      "id,preceptor_id,center_id,latitude,longitude,start_attendance_at," +
        "meditation_start_at,meditation_end_at,status,attendee_count,short_code",
    )
    .eq("id", id)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!data) return json({ error: "not found" }, 404);
  return json(data);
}
