# Compliance & scale-hardening runbook

Pre-launch checklist for the official app. Items marked **(needs decision)** or
**(needs account/infra)** can't be completed from the codebase alone.

## App-store data & privacy

- Host the privacy policy (`docs/privacy.md`, once filled) at a public URL; put
  that URL in both store listings.
- **Apple App Privacy** + **Google Data safety** forms: declare the data in the
  privacy.md table (identifiers, contact info, coarse location, diagnostics).
- **Account deletion (Apple requirement)** — **implemented.** The home-screen
  overflow menu offers "Delete account" → a confirmation dialog →
  `AuthService.deleteAccount()`, which calls the `account/delete` edge route
  (service-role `auth.admin.deleteUser` on the caller's verified `sub`) and then
  signs out. **Scope decided: delete the app login only** — the member's org
  record and historical attendance are org-owned and are left intact (see the
  retention section in `docs/privacy.md`). The deletion is recorded in
  `audit_log` as `account_delete`.

## Authentication

- Interim email/phone OTP is live behind the `AuthService` seam. Swap in
  **Heartfulness SSO** (needs org IdP provisioning) with no UI change.
- **No pre-login PII exposure.** The OTP flow is fully server-side
  (`auth/request-otp`, `auth/verify-otp`): the member's email/phone is resolved
  and used on the server, and only a masked hint (`a***@domain`) is ever
  returned. Session restore uses `auth/me`, which returns *only the caller's own*
  record and requires a valid token. The old anon-readable `participant-lookup`
  route has been removed.
- **OTP rate limiting is implemented** (`ratelimit.ts`): the public `auth/*`
  routes are throttled per Heartfulness ID and per client IP via Upstash
  fixed-window counters (429 + `Retry-After` when exceeded; fails open if Redis
  is unavailable so it never blocks real sign-in). Per-ID caps are tight; per-IP
  caps are generous so a shared venue/carrier NAT isn't locked out — **tune the
  constants in `ratelimit.ts` per deployment**, and confirm them against the
  venue-login pattern during the mass-event load test. `auth/request-otp` still
  confirms an ID exists (the masked hint), so enumeration is slowed, not
  eliminated; Heartfulness SSO removes this surface entirely.

## Reliability / scale (needs infra)

The DB write is *not* the bottleneck — a 70k session is still one Postgres row
(`attendee_ids` array + count). The mass-event risks are:

- **Redis durability — checkpointed.** The open session lives in Upstash for its
  ~1h life, but the frozen attendee set is now snapshotted to Postgres
  (`session_checkpoints`) at end-attendance and meditation-start, and
  `meditation-stop` recovers from that checkpoint if the buffer was evicted — so
  a mid-meditation Redis loss no longer strands the in-flight set. Still review
  Upstash persistence/eviction settings and set memory/eviction alerts. Residual
  gap: a loss *during the collecting phase* (before end-attendance) isn't
  checkpointed — affected members simply re-give attendance. A periodic
  collecting-phase checkpoint (cron) could close that if needed.
- **Per-attend response amplification — FIXED.** `attend` used to return the
  entire growing attendee list on every call (SMEMBERS), ~O(n²) at scale. Clients
  now receive only `attendee_count` (Redis SCARD); the full id set is
  materialized just once, at the meditation-stop flush. Keep it that way — never
  add the id array back to a client-facing DTO.
- **Upstash tier limits:** per-command count, bandwidth, and max request/response
  size. A 70k-member set is ~1–2 MB per SMEMBERS; repeated full reads can exceed
  free-tier caps. These are raised by upgrading the plan (easy), but fix the
  amplification above first so you're not paying to move data nobody uses.
- **CORS:** set the `ALLOWED_ORIGINS` function secret to the real web origin(s)
  in prod (defaults to `*` only when unset — see `cors.ts`).
- **Load test** the mass-event flush path against the 40k–70k+ target on staging
  before any real event — see `scripts/load-test/attend.js`. Watch the geo-bucket
  fan-out and the single-flush write; confirm free-tier limits hold or budget up.

## Member availability & reach

The backend is globally reachable and always-on; "can any member use it anywhere"
is gated by these, not by the network:

- **OTP delivery.** Login needs the code to reach the member's contact on file.
  Email is globally reliable — prefer it. **Phone/SMS OTP is region-dependent**
  (deliverability + cost vary by country/carrier and provider); don't rely on SMS
  for international members without validating the SMS provider's coverage.
- **App distribution is per-country.** App Store / Play Store availability is
  chosen per territory at release. The **web build** works anywhere with the URL;
  the **iOS target doesn't exist yet** (no iPhone app until it's created + signed
  on macOS — see `docs/release.md`).
- **Language.** Currently English-only (only the login screen is localized).
  Members anywhere can use it, but non-English speakers hit a UX wall until the
  i18n coverage is extended.
- **Attendance is location-bound by design.** Sign-in/viewing works anywhere, but
  *giving attendance* matches the member to a nearby active session by GPS (or a
  session short-code/QR). This is intentional, not a limitation to "fix".

## Security review

- Run `/security-review` on the branch (and a third-party pen test before public
  launch), focusing on the edge function auth guard, RLS, and the JWT handling.

## Monitoring (needs account)

- Set the `SENTRY_DSN` build define to receive crashes/errors; build release with
  `--split-debug-info` so stack traces symbolicate (see `docs/release.md`).
- Build Supabase + Upstash dashboards/alerts (function error rate from the
  structured logs, DB rows, Redis memory).
