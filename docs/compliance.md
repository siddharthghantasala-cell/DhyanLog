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
- Remove the interim pre-login PII exposure: `participant-lookup` is anon-readable
  so the client can start OTP. SSO removes the need for it; until then, consider a
  server-side OTP-send route so member email never reaches the client.

## Reliability / scale (needs infra)

- **Redis durability:** the open session lives only in Upstash for its ~1h life;
  a buffer loss mid-session loses the in-flight attendee set. Review Upstash
  persistence/eviction settings and set alerts on memory/evictions for the prod
  database before a mass event.
- **CORS:** set the `ALLOWED_ORIGINS` function secret to the real web origin(s)
  in prod (defaults to `*` only when unset — see `cors.ts`).
- **Load test** the mass-event flush path against the 40k–70k+ target on staging
  before any real event — see `scripts/load-test/attend.js`. Watch the geo-bucket
  fan-out and the single-flush write; confirm free-tier limits hold or budget up.

## Security review

- Run `/security-review` on the branch (and a third-party pen test before public
  launch), focusing on the edge function auth guard, RLS, and the JWT handling.

## Monitoring (needs account)

- Set the `SENTRY_DSN` build define to receive crashes/errors; build release with
  `--split-debug-info` so stack traces symbolicate (see `docs/release.md`).
- Build Supabase + Upstash dashboards/alerts (function error rate from the
  structured logs, DB rows, Redis memory).
