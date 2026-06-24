# DhyanLog

A meditation **attendance** app for the Heartfulness organization. It records
**when, where, who, and for how long** people meditate, and is built to scale from
sessions of 1–3 people to mass events of 40,000–70,000+ — happening continuously
worldwide.

A session leader (**preceptor**) starts an attendance window; attendees (**abhyasis**)
mark attendance; the session then runs and ends. Participants are identified by their
**Heartfulness ID**.

## The one idea that shapes everything

**One database write per session — never one per attendee.** Fanning N attendee writes
into the database per session is what wouldn't scale. Instead, each open session lives
entirely in a **hot buffer** (Redis) for its whole life; attendees are appended there
(atomic, de-duplicated). When the preceptor stops the meditation, the buffer **flushes
exactly once**, writing a single row with the attendee list as an array + a count.

```
collecting ──(abhyasis join, in Redis)──► meditating ──► STOP = single Postgres write
   start attendance        give attendance       start            (the only write)
```

So whether 3 or 70,000 people attend, it's one row, one write.

## Architecture

```
Flutter app ─(AttendanceService / ParticipantRepository)─► Mock (no config)
                                                            HTTP  ─► Supabase Edge Function `api`
                                                                        │
                                                  ┌─────────────────────┤
                                                  ▼                     ▼
                                            Upstash Redis         Supabase Postgres
                                          open sessions (hot)    one row per session
                                          geo-bucket matching    monthly analytics job
```

- **Frontend:** Flutter (Riverpod). Login by Heartfulness ID; role-based preceptor /
  abhyasi modes with distinct themes; one large central action button.
- **Backend:** a single routed Supabase Edge Function (`supabase/functions/api`) over an
  Upstash Redis buffer; the only Postgres write is the meditation-stop flush.
- **Swap point:** `lib/state/providers.dart` chooses the real backend when
  `SUPABASE_URL` + `SUPABASE_ANON_KEY` are provided, else the in-memory mock.

## Data model (`supabase/migrations`)
- `participants` — Heartfulness members (dummy/seed now; real internal DB later).
- `meditation_centers` — known locations for tagging/disambiguation.
- `meditation_sessions` — **one finalized row per session**; `attendee_ids text[]` +
  `attendee_count`.
- `attendance_expanded` — normalized rows for analytics, built **off the hot path** by
  the monthly `expand_attendance()` job.

## Run it

### Mock backend (no setup)
```sh
flutter run            # uses the in-memory mock; seeded IDs below
```

### Real backend (Supabase + Upstash)
```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```
Full deploy steps: [`docs/phase3-deploy.md`](docs/phase3-deploy.md).

### Seeded IDs
- Preceptor: `HFN-PREC-001`, `HFN-PREC-002` · Master: `HFN-MASTER-000`
- Abhyasi: `HFN-ABHY-001`, `HFN-ABHY-002`, `HFN-ABHY-003`

## Test
```sh
flutter analyze
flutter test           # lifecycle, dedupe, ambiguity→code, out-of-range, freeze, boot
```

## Project layout
```
lib/
  models/      contracts (participant, center, session, attend-result)
  services/    AttendanceService + ParticipantRepository (mock/ and http/ impls)
  state/       Riverpod providers (the mock↔real swap point)
  ui/          login, home, preceptor session, abhyasi attend
supabase/
  migrations/  schema + monthly-job scheduling
  functions/api/  the routed edge function (Redis buffer + flush)
docs/          deployment runbook
FUTURE_VENTURES.md   deferred ideas (language, voice, maps, SSO, ML, …)
```

## Status
Phases 1–3 complete and verified; backend deployed. Roadmap and deferred features in
[`FUTURE_VENTURES.md`](FUTURE_VENTURES.md).
