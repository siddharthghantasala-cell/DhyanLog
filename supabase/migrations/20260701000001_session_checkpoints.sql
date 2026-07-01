-- Durability checkpoint for in-flight sessions. A session lives in Redis for its
-- whole ~1h life and is written to `meditation_sessions` only at the
-- meditation-stop flush. If Redis loses the session mid-meditation (eviction /
-- provider incident) the in-flight attendee set would be gone. This table holds
-- a copy of the frozen attendee set (written at end-attendance / meditation
-- start) so meditation-stop can still finalize after a buffer loss.
--
-- This does NOT change the "one finalized row per session" invariant:
-- `meditation_sessions` still gets exactly one write per session. Checkpoints are
-- a small, bounded number of writes per session (never per-attendee) to a
-- separate table, and the row is deleted once the session is flushed.
create table if not exists session_checkpoints (
  id                    text        primary key,
  preceptor_id          text        not null,
  center_id             text,
  latitude              double precision not null,
  longitude             double precision not null,
  start_attendance_at   timestamptz not null,
  meditation_start_at   timestamptz,
  short_code            text        not null,
  attendee_ids          text[]      not null default '{}',
  attendee_count        int         not null default 0,
  updated_at            timestamptz not null default now()
);

-- Deny-all by default: only the service-role key (the edge function) touches it.
alter table session_checkpoints enable row level security;
