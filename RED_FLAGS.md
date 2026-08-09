# 🚩 RED FLAGS — read before any public / production release

This app is a **closed-MVP build**. Several things are deliberately unsafe or
incomplete so the MVP can be tested quickly. **None of the 🔴 items below may ship
to the public.** This file is the single place that lists them; operational launch
tasks live in [`docs/launch-checklist.md`](docs/launch-checklist.md).

Last reviewed: 2026-08-05.

---

## 🔴 Blocking — must be fixed before a public release

### 1. Anyone with the build can sign in as anyone (dev-auth bypass)
The client build ships a shared `DEV_AUTH_SECRET` that the edge function trusts:
it takes the caller's Heartfulness ID straight from a header and synthesizes an
authenticated session. **Whoever holds the build can impersonate any member.**
- Gated by the `DEV_AUTH_SECRET` function secret — **inert when unset**
  (`lib/config/app_config.dart`: `devAuth`; `supabase/functions/api/index.ts` dev branch).
- The secret is kept **out of this repo** (gitignored `config/dev.json` + build scripts)
  precisely because the repo is public: committing it would widen impersonation from
  "whoever holds the build" to anyone on the internet. The Supabase URL and anon key
  *are* committed — the anon key is public by design.
- **Before production:** `supabase secrets unset DEV_AUTH_SECRET` **and redeploy `api`**,
  then confirm a dev-auth header no longer logs anyone in.

### 2. No real proof of identity in the MVP
Login is a single **Heartfulness-ID** step — no OTP, no password. The backend only
checks that the ID exists and signs in as that member. This is now the *only* flow a
normal build presents (`AUTH_MODE` defaults to `id`).
- The production **OTP flow is built but dormant** (behind the `AuthService` seam,
  ready for Heartfulness SSO). Reachable with `--dart-define=AUTH_MODE=otp`, and
  covered by a widget test so it doesn't rot.
- **Before production:** build with `AUTH_MODE=otp` (or wire SSO), unset dev-auth
  (#1), and verify the ID-existence path is gone.

### 3. Unknown IDs are admitted under a placeholder
An unknown ID is let in anyway, creating a real `participants` row (`Guest <id>`,
role inferred from a `PREC` substring). Intentional for MVP testing; **an open door
in production.** Removed automatically once dev-auth is off (#1), since the placeholder
path is only reached on the dev-auth branch — verify this after unsetting the secret.

### 4. Android release build is signed with the debug key
`android/app/build.gradle.kts` → `release { signingConfig = signingConfigs.getByName("debug") }`.
Play Store **will reject** a debug-signed bundle.
- **Before store upload:** generate an upload keystore, wire a real `release` signing
  config (keystore out of git), and bump `version:` from `0.1.0+1` in `pubspec.yaml`.

---

## 🟠 Handle with care — data & privacy

### 5. Real personal data (PII) must never be committed
Center-coordinator phone numbers and preceptor contact details are **gitignored**
(`Gachibowli Center Details…csv`, `*Preceptor Details*.csv`) and were loaded into the
live DB via the Management API — **no migration file contains people's data.** Keep it
that way: no PII in git, ever. Credentials live only in gitignored files (`.env`,
`config/*.json`, `.dev_auth_secret.txt`).

### 6. Placeholder venue radii
Per-venue `check_radius_meters` values are placeholders. Replace with real GPS
coordinates + sensibly small radii (crowd-scaled) before real capture. (Awaiting the
12 satsang-center coordinates.)

---

## 🟡 Known gaps — accepted for MVP, revisit before scale

### 7. Mid-session Redis loss strands a session (durability)
The merged single-tap flow (Start → Stop) keeps a session *meditating with attendance
open* for its whole ~1h life in the hot buffer (Upstash, 3h key TTL) and flushes once
at stop. There is **no separate freeze step, so `session_checkpoints` is not written**
on the happy path (schema + `meditation-stop` recovery read are retained). If Redis is
lost mid-session, that session is lost and members re-attend in a restarted session.
- **If sessions could outlive the buffer TTL, or losses become unacceptable:** add a
  periodic checkpoint (cron) that snapshots the growing attendee set. See
  [`docs/compliance.md`](docs/compliance.md).

### 8. Two preceptors still lack Heartfulness IDs
Sreehari Naguralu and GL Rao are not in the DB — add once their IDs are provided.

### 9. iOS signing / free-tier limits
iOS target is scaffolded; signing needs an Apple account. Confirm Upstash/Supabase
free-tier limits hold under a mass-event load test (subscription bump, no re-architecting).

---

## ✅ Pre-production gate (quick checklist)
- [ ] `supabase secrets unset DEV_AUTH_SECRET` + redeploy `api` (#1)
- [ ] Verify no dev-auth login and no placeholder admission after unset (#1, #3)
- [ ] OTP / SSO is the live sign-in path — build with `AUTH_MODE=otp` (#2)
- [ ] Real Android upload keystore + `release` signing + version bump (#4)
- [ ] No PII in git; real venue coordinates/radii seeded (#5, #6)
- [ ] Decide on session durability for scale (#7)
