-- Audit trail for preceptor lifecycle actions (start / end-attendance /
-- meditation-start / meditation-stop). Written by the edge function with the
-- service-role key. NOT written per-attendee — attends are never row-per-person.
create table if not exists audit_log (
  id                    bigint generated always as identity primary key,
  at                    timestamptz not null default now(),
  actor_heartfulness_id text        not null,
  action                text        not null
                          check (action in (
                            'session_start',
                            'end_attendance',
                            'meditation_start',
                            'meditation_stop'
                          )),
  session_id            text        not null,
  detail                jsonb       not null default '{}'::jsonb
);

create index if not exists audit_log_session_idx on audit_log (session_id);
create index if not exists audit_log_actor_idx on audit_log (actor_heartfulness_id);
create index if not exists audit_log_at_idx on audit_log (at desc);

-- Deny-all by default: only the service-role key (used by the edge function)
-- may read or write. No permissive policies, matching the other PII tables.
alter table audit_log enable row level security;
