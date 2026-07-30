# DhyanLog

A meditation **attendance** app for the Heartfulness organization. It records
**when, where, who, and for how long** people meditate, and is built to scale from
sessions of 1–3 people to mass events of 40,000–70,000+ — happening continuously
worldwide.

A session leader (**preceptor**) starts an attendance window; attendees (**abhyasis**)
mark attendance; the session then runs and ends. Participants are identified by their
**Heartfulness ID** — see **Auth & authorization** for how sign-in works.

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

So whether 3 or 70,000 people attend, it's one row, one write. Clients only ever
receive the running **count**, never the id list (which would be O(n²) at scale).

## Sessions: satsang vs regular

Every session is one of two types, decided **server-side** (never trusted from the client):

- **Satsang** — held at a known **meditation center**. The session anchors on the
  center's coordinates and uses that center's **check radius** (`check_radius_meters`),
  so a large gathering can capture attendance across the whole venue.
- **Regular** — a home / small session with no center. It anchors on the preceptor's GPS
  and uses a tight default radius (~30 m).

The chosen `type` and effective `match_radius_meters` are persisted on the session (and
its durability checkpoint), and the radius is clamped to a sane band. Attendance matching
in the Redis buffer is **per-session**, so a wide satsang and a tight home session can run
at the same time without cross-capturing.

## Architecture

```
Flutter app ─(AttendanceService / AuthService seams)─► Mock (no config)
                                                        HTTP ─► Supabase Edge Function `api`
                                                                    │
                                              ┌─────────────────────┤
                                              ▼                     ▼
                                        Upstash Redis         Supabase Postgres
                                      open sessions (hot)    one row per session
                                      geo-bucket matching    + audit / checkpoints
```

- **Frontend:** Flutter (Riverpod). Role-based preceptor / abhyasi modes with distinct
  themes; one large central action button. Dark mode; fully localized (English,
  translation-ready). Offline attend queue; typed errors with retry/offline states.
  In-session **notification muting** and a personal **session history** (your own
  attended / led sessions, derived from the one-row-per-session record).
- **Backend:** a single routed Supabase Edge Function (`supabase/functions/api`) over an
  Upstash Redis buffer; the only `meditation_sessions` write is the meditation-stop flush.
- **Swap point:** `lib/state/providers.dart` chooses the real backend when
  `SUPABASE_URL` + `SUPABASE_ANON_KEY` are provided, else the in-memory mock.

## Auth & authorization

**How login works in the current MVP build:** a single **Heartfulness-ID** step, with
**no proof of identity** (no OTP, no password). The app asks the backend whether the ID
exists and signs in as that member; an **unknown ID is still admitted, under a generated
placeholder** (preceptor if the id contains `PREC`, else abhyasi). This is intentional for
closed MVP testing and is gated by `DEV_AUTH_SECRET` — the secret is shared between the
build and the function, so anyone holding the build can sign in as any member. **Not for
public/production.**

- **Role authorization is still enforced**, MVP or not: every route requires
  public / member / leader, resolved from the member's role in the database. Preceptors
  can only manage their own sessions.
- **RLS deny-all** on all tables; clients never touch Postgres directly (service-role
  edge function only). In-app **account deletion** (removes the login only).
- Structured request logs + an **audit trail** for session lifecycle + account deletion.
- Config/secrets via `--dart-define` (client) and function secrets (server); see
  `config/README.md`. CORS allowlist via `ALLOWED_ORIGINS`.

**Production auth (built, but dormant for the MVP):** a two-step server-side **OTP** flow
lives in the code — the client sends an ID and a code and never sees the member's
email/phone (only a masked `a***@domain` hint), rate-limited per-ID + per-IP, behind the
`AuthService` seam so **Heartfulness SSO** can swap in. It becomes the only way in once
`DEV_AUTH_SECRET` is unset and the function redeployed.

## Data model (`supabase/migrations`)
- `participants` — Heartfulness members (dummy/seed now; real internal DB later).
- `meditation_centers` — known locations for tagging/disambiguation, each with a
  per-center **`check_radius_meters`** capture radius.
- `meditation_sessions` — **one finalized row per session**; `attendee_ids text[]` +
  `attendee_count`; `type` (satsang/regular) + `match_radius_meters`.
- `attendance_expanded` — normalized rows for analytics, built **off the hot path** by
  the monthly `expand_attendance()` job.
- `audit_log` — session lifecycle + account-deletion actions (never per-attendee).
- `session_checkpoints` — durability copy of the frozen attendee set so a mid-meditation
  Redis loss can still be finalized.

## Run it

### Mock backend (no setup) — the easy way to try it
```sh
flutter run            # in-memory mock; no backend, no OTP delivery
```
Sign in with a seeded ID and **any 6-digit code** (the mock accepts anything). Location
is a simulated picker, so no GPS permission is needed. Works on a connected phone too
(`flutter run -d <device>`).

### Real backend (Supabase + Upstash)
```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```
Requires the `api` function **deployed** (with all migrations applied) and an SMTP
provider configured for OTP email. Deploy + launch steps:
[`docs/launch-checklist.md`](docs/launch-checklist.md), [`docs/release.md`](docs/release.md).

### MVP dev login (one-step ID sign-in) — non-production
```sh
flutter run --dart-define-from-file=config/dev.json   # config carries DEV_AUTH_SECRET
```
With `DEV_AUTH_SECRET` present, login is a single Heartfulness-ID step (no OTP) and
unknown IDs are let in under a placeholder — see **Security & auth**. Keep this to closed
testing; unset the secret and redeploy before any public/production release.

### Seeded IDs
- Preceptor: `HFN-PREC-001`, `HFN-PREC-002` · Master: `HFN-MASTER-000`
- Abhyasi: `HFN-ABHY-001`, `HFN-ABHY-002`, `HFN-ABHY-003`

## Test
```sh
flutter analyze && flutter test                    # 97 tests
cd supabase/functions/api && deno fmt --check . && deno check index.ts && deno test -A   # 48 tests
```
CI runs all of the above plus a web build and an iOS compile-check
(`.github/workflows/ci.yml`).

## Project layout
```
lib/
  models/      contracts (participant, center, session, attend-result, pending-attend)
  services/    auth/ (AuthService + OTP), http/ (ApiClient + impls), mock/,
               offline/ (attend queue), observability/ (telemetry)
  state/       Riverpod providers (the mock↔real swap point)
  ui/          login, home, preceptor session, abhyasi attend, error presentation
  l10n/        ARB strings + generated localizations
  theme/       role themes, dark mode, design tokens
supabase/
  migrations/  schema, audit, checkpoints, monthly-job scheduling
  functions/api/  the routed edge function (auth/OTP, buffer + flush, rate limiting)
android/ ios/  mobile targets
docs/          launch checklist, release, privacy, compliance runbooks
```

## Status
Production-hardening complete and verified (auth, resilience, observability, CI/CD,
UI/i18n, compliance, checkpointing). Web + Android + iOS targets build; the iOS target
is scaffolded (signing needs an Apple account). Remaining work is accounts / infra /
legal / store submission — tracked in
[`docs/launch-checklist.md`](docs/launch-checklist.md). Deferred ideas:
[`FUTURE_VENTURES.md`](FUTURE_VENTURES.md).
