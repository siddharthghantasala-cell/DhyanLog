import { SupabaseClient } from "./deps.ts";
import {
  DEFAULT_REGULAR_RADIUS_METERS,
  SessionMeta,
  type SessionType,
} from "./buffer.ts";

/// Durability checkpoint for an in-flight session. Written when attendance is
/// ended and when meditation starts, so that if Redis loses the session before
/// the meditation-stop flush, the frozen attendee set can still be recovered and
/// finalized. See migration `..._session_checkpoints.sql`.

export interface CheckpointRow {
  id: string;
  preceptor_id: string;
  center_id: string | null;
  latitude: number;
  longitude: number;
  start_attendance_at: string;
  meditation_start_at: string | null;
  short_code: string;
  attendee_ids: string[];
  attendee_count: number;
  type: SessionType | null;
  match_radius_meters: number | null;
}

/// Snapshot -> row. Pure, so the mapping is unit-testable without a DB.
export function metaToRow(
  meta: SessionMeta,
  attendees: string[],
): CheckpointRow {
  return {
    id: meta.id,
    preceptor_id: meta.preceptorId,
    center_id: meta.centerId,
    latitude: meta.latitude,
    longitude: meta.longitude,
    start_attendance_at: meta.startAttendanceAt,
    meditation_start_at: meta.meditationStartAt,
    short_code: meta.shortCode,
    attendee_ids: attendees,
    attendee_count: attendees.length,
    type: meta.type,
    match_radius_meters: meta.matchRadiusMeters,
  };
}

/// Row -> snapshot for recovery. The set is frozen by the time a checkpoint
/// exists, so status is `meditating` when a start time is present, else
/// `collecting`; the stop path overwrites status to `ended` anyway.
export function rowToMeta(row: CheckpointRow): SessionMeta {
  return {
    id: row.id,
    preceptorId: row.preceptor_id,
    centerId: row.center_id,
    latitude: row.latitude,
    longitude: row.longitude,
    startAttendanceAt: row.start_attendance_at,
    meditationStartAt: row.meditation_start_at,
    meditationEndAt: null,
    status: row.meditation_start_at ? "meditating" : "collecting",
    shortCode: row.short_code,
    frozen: true,
    // Legacy checkpoints predate these; fall back to a safe regular default.
    type: row.type ?? "regular",
    matchRadiusMeters: row.match_radius_meters ?? DEFAULT_REGULAR_RADIUS_METERS,
  };
}

/// Upsert the checkpoint (keyed by session id). Best-effort at the call sites:
/// a failure here must not break ending attendance / starting meditation.
export async function writeCheckpoint(
  db: SupabaseClient,
  meta: SessionMeta,
  attendees: string[],
): Promise<string | null> {
  const { error } = await db
    .from("session_checkpoints")
    .upsert({
      ...metaToRow(meta, attendees),
      updated_at: new Date().toISOString(),
    });
  return error ? error.message : null;
}

/// Read a checkpoint for recovery; null if none exists.
export async function readCheckpoint(
  db: SupabaseClient,
  id: string,
): Promise<{ meta: SessionMeta; attendees: string[] } | null> {
  const { data, error } = await db
    .from("session_checkpoints")
    .select(
      "id,preceptor_id,center_id,latitude,longitude,start_attendance_at," +
        "meditation_start_at,short_code,attendee_ids,attendee_count," +
        "type,match_radius_meters",
    )
    .eq("id", id)
    .maybeSingle();
  if (error || !data) return null;
  const row = data as unknown as CheckpointRow;
  return { meta: rowToMeta(row), attendees: row.attendee_ids ?? [] };
}

/// Remove the checkpoint once the session is flushed (or being cleaned up).
export async function deleteCheckpoint(
  db: SupabaseClient,
  id: string,
): Promise<void> {
  await db.from("session_checkpoints").delete().eq("id", id);
}
