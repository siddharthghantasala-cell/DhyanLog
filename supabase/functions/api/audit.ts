import { SupabaseClient } from "./deps.ts";

/// Audited lifecycle actions. Deliberately excludes `attend`: attends happen
/// per-attendee at mass-event scale and are never written individually (the
/// whole architecture avoids that). The session actions are once-per-session
/// (`session_start` and the single `meditation_stop` flush — the merged flow has
/// no separate end-attendance/meditation-start steps); `account_delete` is a
/// per-member action with no session (sessionId is null).
export type AuditAction =
  | "session_start"
  | "meditation_stop"
  | "account_delete";

export interface AuditEntry {
  actorHeartfulnessId: string;
  action: AuditAction;
  sessionId?: string; // null for non-session actions like account_delete
  detail?: Record<string, unknown>;
}

/// Append an audit row. Best-effort: a failure here must never break the user's
/// action, so the caller should not await-and-throw on it. Returns the error (if
/// any) for logging rather than throwing.
export async function recordAudit(
  db: SupabaseClient,
  entry: AuditEntry,
): Promise<string | null> {
  const { error } = await db.from("audit_log").insert({
    actor_heartfulness_id: entry.actorHeartfulnessId,
    action: entry.action,
    session_id: entry.sessionId ?? null,
    detail: entry.detail ?? {},
  });
  return error ? error.message : null;
}
