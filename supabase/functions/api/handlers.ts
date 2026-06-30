import { createClient, SupabaseClient } from "./deps.ts";
import { Buffer, SessionMeta } from "./buffer.ts";
import { json } from "./cors.ts";

function db(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

function generateId(): string {
  return `sess_${Date.now().toString(36)}_${crypto.randomUUID().slice(0, 8)}`;
}

function generateCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no ambiguous chars
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

/// Snake_case DTO matching the Flutter MeditationSession.fromJson contract.
function sessionDto(meta: SessionMeta, attendeeIds: string[]) {
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
    attendee_ids: attendeeIds,
    attendee_count: attendeeIds.length,
    short_code: meta.shortCode,
  };
}

export async function lookupParticipant(body: any): Promise<Response> {
  const id = (body.heartfulnessId ?? "").toString().trim();
  if (!id) return json({ error: "heartfulnessId required" }, 400);
  const { data, error } = await db()
    .from("participants")
    .select("heartfulness_id,name,age,address,email,phone,role")
    .ilike("heartfulness_id", id)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!data) return json({ participant: null });
  return json({ participant: data });
}

export async function startSession(
  buffer: Buffer,
  body: any,
): Promise<Response> {
  const { preceptorId, centerId, latitude, longitude } = body;
  if (!preceptorId || latitude == null || longitude == null) {
    return json({ error: "preceptorId, latitude, longitude required" }, 400);
  }
  const meta: SessionMeta = {
    id: generateId(),
    preceptorId,
    centerId: centerId ?? null,
    latitude,
    longitude,
    startAttendanceAt: new Date().toISOString(),
    meditationStartAt: null,
    meditationEndAt: null,
    status: "collecting",
    shortCode: generateCode(),
    frozen: false,
  };
  await buffer.createSession(meta);
  return json(sessionDto(meta, []));
}

export async function attend(buffer: Buffer, body: any): Promise<Response> {
  const heartfulnessId = (body.heartfulnessId ?? "").toString().trim();
  if (!heartfulnessId) return json({ error: "heartfulnessId required" }, 400);

  // Code / QR fallback path.
  if (body.code) {
    const id = await buffer.resolveCode(body.code.toString());
    const meta = id ? await buffer.getMeta(id) : null;
    if (!meta || meta.frozen || meta.status !== "collecting") {
      return json({ outcome: "notFound" });
    }
    return await joinAndRespond(buffer, meta, heartfulnessId);
  }

  // GPS path.
  if (body.latitude == null || body.longitude == null) {
    return json({ error: "latitude/longitude or code required" }, 400);
  }
  const nearby = await buffer.findNearby(body.latitude, body.longitude);
  if (nearby.length === 0) return json({ outcome: "notFound" });
  if (nearby.length > 1) {
    const candidates = await Promise.all(
      nearby.map(async (m) => sessionDto(m, await buffer.attendees(m.id))),
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
  const attendees = await buffer.attendees(meta.id);
  return json({
    outcome: added ? "joined" : "alreadyJoined",
    session: sessionDto(meta, attendees),
  });
}

async function mutateMeta(
  buffer: Buffer,
  sessionId: string,
  fn: (m: SessionMeta) => SessionMeta,
): Promise<SessionMeta | null> {
  const meta = await buffer.getMeta(sessionId);
  if (!meta) return null;
  const updated = fn(meta);
  await buffer.putMeta(updated);
  return updated;
}

export async function endAttendance(
  buffer: Buffer,
  body: any,
): Promise<Response> {
  const updated = await mutateMeta(buffer, body.sessionId, (m) => ({
    ...m,
    frozen: true,
  }));
  if (!updated) return json({ error: "session not active" }, 404);
  return json(sessionDto(updated, await buffer.attendees(updated.id)));
}

export async function meditationStart(
  buffer: Buffer,
  body: any,
): Promise<Response> {
  const updated = await mutateMeta(buffer, body.sessionId, (m) => ({
    ...m,
    status: "meditating",
    meditationStartAt: new Date().toISOString(),
  }));
  if (!updated) return json({ error: "session not active" }, 404);
  return json(sessionDto(updated, await buffer.attendees(updated.id)));
}

/// The single flush: finalize, write ONE Postgres row, evict from the buffer.
export async function meditationStop(
  buffer: Buffer,
  body: any,
): Promise<Response> {
  const meta = await buffer.getMeta(body.sessionId);
  if (!meta) return json({ error: "session not active" }, 404);
  const attendees = await buffer.attendees(meta.id);
  const finalized: SessionMeta = {
    ...meta,
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
  return json(sessionDto(finalized, attendees));
}

export async function getSession(buffer: Buffer, body: any): Promise<Response> {
  const id = body.sessionId;
  const meta = await buffer.getMeta(id);
  if (meta) {
    return json(sessionDto(meta, await buffer.attendees(id)));
  }
  // Finalized -> read the row.
  const { data, error } = await db()
    .from("meditation_sessions")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!data) return json({ error: "not found" }, 404);
  return json(data);
}
