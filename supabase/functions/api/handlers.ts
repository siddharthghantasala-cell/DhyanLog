import { type AuditAction, recordAudit } from "./audit.ts";
import { type Member } from "./auth.ts";
import {
  Buffer,
  DEFAULT_REGULAR_RADIUS_METERS,
  MAX_RADIUS_METERS,
  SessionMeta,
  type SessionType,
} from "./buffer.ts";
import { getCenter } from "./centers.ts";
import { deleteCheckpoint, readCheckpoint } from "./checkpoint.ts";
import { json } from "./cors.ts";
import { db } from "./db.ts";
import {
  cleanString,
  optionalString,
  pageLimit,
  pageOffset,
  safeFilterId,
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
    type: meta.type,
    match_radius_meters: meta.matchRadiusMeters,
  };
}

export async function startSession(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<Response> {
  const centerId = optionalString(body.centerId, 64);
  if (centerId === null) return json({ error: "invalid centerId" }, 400);

  // The session's type, anchor, and radius are all decided here (server-side),
  // never trusted from the client:
  //   * a center id  -> satsang: anchor on the CENTER, radius from the center.
  //   * no center id -> regular: anchor on the preceptor's GPS, tight default.
  let type: SessionType;
  let anchorLat: number;
  let anchorLng: number;
  let radius: number;
  if (centerId) {
    const center = await getCenter(db(), centerId);
    if (!center) return json({ error: "unknown center" }, 400);
    type = "satsang";
    anchorLat = center.latitude;
    anchorLng = center.longitude;
    radius = center.checkRadiusMeters;
  } else {
    if (!validLatitude(body.latitude) || !validLongitude(body.longitude)) {
      return json({ error: "valid latitude and longitude required" }, 400);
    }
    type = "regular";
    anchorLat = body.latitude;
    anchorLng = body.longitude;
    radius = DEFAULT_REGULAR_RADIUS_METERS;
  }
  // Clamp to a sane band: never below the regular default, never above the cap
  // that keeps matches inside the geo-bucket coverage.
  radius = Math.min(
    Math.max(Math.round(radius), DEFAULT_REGULAR_RADIUS_METERS),
    MAX_RADIUS_METERS,
  );

  const meta: SessionMeta = {
    id: generateId(),
    preceptorId: member.heartfulnessId, // from the verified token, not the body
    centerId: centerId ?? null,
    latitude: anchorLat,
    longitude: anchorLng,
    startAttendanceAt: new Date().toISOString(),
    // Attendance opens and meditation begins together — a single "Start" action.
    // The window stays open (status `meditating`) so latecomers still count,
    // until the one meditation-stop flush.
    meditationStartAt: new Date().toISOString(),
    meditationEndAt: null,
    status: "meditating",
    shortCode: generateCode(),
    frozen: false,
    type,
    matchRadiusMeters: radius,
  };
  await buffer.createSession(meta);
  await audit(member, "session_start", meta.id, { type, radius });
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
    if (!meta || meta.status !== "meditating") {
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

/// The single flush: finalize, write ONE Postgres row, evict from the buffer.
/// Recovers from the durability checkpoint if the buffer lost the session, so a
/// mid-meditation Redis eviction can't strand an in-flight attendee set.
export async function meditationStop(
  buffer: Buffer,
  body: any,
  member: Member,
): Promise<Response> {
  const sessionId = cleanString(body.sessionId, 128);
  if (!sessionId) return json({ error: "sessionId required" }, 400);

  // Prefer the live buffer; fall back to the checkpoint if it was evicted.
  let source = await buffer.getMeta(sessionId);
  let attendees: string[];
  const fromBuffer = source !== null;
  if (source) {
    // The one place the full set is materialized on the happy path.
    attendees = await buffer.attendees(sessionId);
  } else {
    const recovered = await readCheckpoint(db(), sessionId);
    if (!recovered) return json({ error: "session not active" }, 404);
    source = recovered.meta;
    attendees = recovered.attendees;
  }
  if (!ownsSession(source, member)) {
    return json({ error: "not your session" }, 403);
  }

  const finalized: SessionMeta = {
    ...source,
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
    type: finalized.type ?? null,
    match_radius_meters: finalized.matchRadiusMeters ?? null,
  });
  if (error) return json({ error: error.message }, 500);

  if (fromBuffer) await buffer.evict(finalized);
  await deleteCheckpoint(db(), finalized.id);
  await audit(member, "meditation_stop", finalized.id, {
    attendee_count: attendees.length,
    recovered: !fromBuffer,
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

/// The caller's own meditation history: sessions they attended, plus (for a
/// preceptor) sessions they led, newest first.
///
/// Derived entirely from the existing one-row-per-session record — the
/// `attendee_ids` array is matched with a GIN-indexed containment lookup, so no
/// per-attendee table and no extra write path exists to keep in sync. The array
/// itself is NEVER returned: callers get their own row's metadata and a count,
/// never the identities of everyone else in the session.
///
/// Identity is taken from the verified token, never the body, so a member cannot
/// request somebody else's history.
export async function sessionHistory(
  body: any,
  member: Member,
): Promise<Response> {
  const id = member.heartfulnessId;
  // Ids come from our own participants table, but they are interpolated into a
  // PostgREST filter string below — validate rather than assume.
  if (!safeFilterId(id)) {
    return json({ error: "unsupported member id format" }, 400);
  }
  const limit = pageLimit(body.limit, 50, 200);
  const offset = pageOffset(body.offset);

  // One query, not two: `or` keeps offset/limit paging correct across both
  // halves (paging two separate queries and merging them would drop rows).
  // Postgres serves this as a BitmapOr over the gin + preceptor indexes.
  const { data, error } = await db()
    .from("meditation_sessions")
    .select(
      "id,preceptor_id,center_id,latitude,longitude,start_attendance_at," +
        "meditation_start_at,meditation_end_at,status,attendee_count,short_code",
    )
    .or(`preceptor_id.eq.${id},attendee_ids.cs.{${id}}`)
    .eq("status", "ended")
    .order("start_attendance_at", { ascending: false })
    .range(offset, offset + limit - 1);
  if (error) return json({ error: error.message }, 500);

  const sessions = (data ?? []).map((row: any) => ({
    ...row,
    // Lets the client label an entry "You led this" without a second lookup.
    led: row.preceptor_id === id,
  }));
  return json({ sessions, limit, offset });
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
