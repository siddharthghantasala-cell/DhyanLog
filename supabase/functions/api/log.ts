// Structured request logging for the edge function. One JSON line per request
// (route, status, latency, request id, actor) so logs are queryable in the
// Supabase/Logflare dashboard. Never logs PII or request bodies.

export interface RequestLogFields {
  requestId: string;
  route: string;
  status: number;
  startedAtMs: number;
  actor?: string | null; // heartfulness id (an opaque id, not PII)
  error?: string;
}

/// Build the structured log record (pure, so it's unit-testable).
export function requestLogRecord(
  fields: RequestLogFields,
  nowMs: number,
): Record<string, unknown> {
  const record: Record<string, unknown> = {
    ts: new Date(nowMs).toISOString(),
    level: fields.status >= 500 ? "error" : "info",
    request_id: fields.requestId,
    route: fields.route,
    status: fields.status,
    latency_ms: nowMs - fields.startedAtMs,
  };
  if (fields.actor) record.actor = fields.actor;
  if (fields.error) record.error = fields.error;
  return record;
}

export function logRequest(fields: RequestLogFields): void {
  const record = requestLogRecord(fields, Date.now());
  // console.error routes to the error stream for 5xx so alerts can key off it.
  const line = JSON.stringify(record);
  if (fields.status >= 500) {
    console.error(line);
  } else {
    console.log(line);
  }
}
