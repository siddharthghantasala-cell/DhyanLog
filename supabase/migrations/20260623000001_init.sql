-- DhyanLog initial schema.
-- Design driver: ONE row per meditation session. Attendees are stored as an
-- array (attendee_ids) + a counter (attendee_count), never one row per
-- attendee. A session is written exactly once, at meditation stop (the flush
-- out of the Redis hot buffer).

-- ---------------------------------------------------------------------------
-- Participants — stand-in for the internal Heartfulness member database.
-- In production this is replaced by an adapter over the real system; the app
-- only ever reads it (via the participant-lookup edge function).
-- ---------------------------------------------------------------------------
create table if not exists participants (
  heartfulness_id text primary key,
  name            text not null,
  age             int,
  address         text,
  email           text,
  phone           text,
  role            text not null default 'abhyasi'
                    check (role in ('abhyasi', 'preceptor', 'master')),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Meditation centers — known locations used to tag + disambiguate sessions.
-- ---------------------------------------------------------------------------
create table if not exists meditation_centers (
  id         text primary key,
  name       text not null,
  latitude   double precision not null,
  longitude  double precision not null,
  address    text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Meditation sessions — the single finalized record per session. Rows are
-- inserted by the meditation-stop flush; they are not mutated per-attendee.
-- ---------------------------------------------------------------------------
create table if not exists meditation_sessions (
  id                  text primary key,
  preceptor_id        text not null references participants(heartfulness_id),
  center_id           text references meditation_centers(id),
  latitude            double precision not null,
  longitude           double precision not null,
  start_attendance_at timestamptz not null,
  meditation_start_at timestamptz,
  meditation_end_at   timestamptz,
  status              text not null default 'ended'
                        check (status in ('collecting', 'meditating', 'ended')),
  attendee_ids        text[] not null default '{}',
  attendee_count      int not null default 0,
  short_code          text,
  created_at          timestamptz not null default now()
);

create index if not exists idx_sessions_preceptor on meditation_sessions (preceptor_id);
create index if not exists idx_sessions_center     on meditation_sessions (center_id);
create index if not exists idx_sessions_started    on meditation_sessions (start_attendance_at);

-- ---------------------------------------------------------------------------
-- Analytics expansion target — populated OFF the hot path by a monthly job
-- that unnests attendee_ids. Kept separate so the write path stays one-row.
-- ---------------------------------------------------------------------------
create table if not exists attendance_expanded (
  session_id     text not null references meditation_sessions(id) on delete cascade,
  heartfulness_id text not null,
  session_date   date not null,
  center_id      text,
  primary key (session_id, heartfulness_id)
);

create index if not exists idx_expanded_member on attendance_expanded (heartfulness_id);
create index if not exists idx_expanded_date   on attendance_expanded (session_date);

-- Monthly expansion: idempotently fan out any not-yet-expanded sessions.
create or replace function expand_attendance() returns void
language sql as $$
  insert into attendance_expanded (session_id, heartfulness_id, session_date, center_id)
  select s.id,
         a.hid,
         coalesce(s.meditation_start_at, s.start_attendance_at)::date,
         s.center_id
  from meditation_sessions s
  cross join lateral unnest(s.attendee_ids) as a(hid)
  where s.status = 'ended'
  on conflict do nothing;
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security. The app talks to the DB only through edge functions that
-- use the service-role key (which bypasses RLS). We enable RLS and add NO
-- permissive policies, so the anon/public key cannot read PII or sessions
-- directly. Centers are safe public read.
-- ---------------------------------------------------------------------------
alter table participants         enable row level security;
alter table meditation_sessions  enable row level security;
alter table attendance_expanded  enable row level security;
alter table meditation_centers   enable row level security;

drop policy if exists centers_public_read on meditation_centers;
create policy centers_public_read on meditation_centers
  for select to anon, authenticated using (true);
