# Launch checklist

The code is production-hardened; what remains is almost entirely **accounts,
infra, and content that only you can provide**. Work top to bottom — earlier
items unblock later ones. Each item says who/what it needs and links the
relevant doc.

Legend: ☐ = to do · 🔴 blocker for any public launch · 🟡 needed before a mass
event · 🟢 nice-to-have / post-launch.

---

## 1. Backend deploy & environments

- ☐ 🔴 **Create separate Supabase projects** for `staging` and `prod` (today
  there is one). Keep dev on the mock or a throwaway project.
- ☐ 🔴 **`supabase link` + `supabase db push`** each environment. This must run
  **all migrations**, including the two newest:
  `20260701000000_audit_account_delete.sql` and
  `20260701000001_session_checkpoints.sql`.
- ☐ 🔴 **Deploy the `api` edge function** to each env (`supabase functions
  deploy api`). CI can do this on merge — see `.github/workflows/deploy-functions.yml`.
- ☐ 🔴 **Set function secrets** per env: `UPSTASH_REDIS_REST_URL`,
  `UPSTASH_REDIS_REST_TOKEN`, and `ALLOWED_ORIGINS` (the real web origin(s);
  leaving it unset defaults CORS to `*` — see `cors.ts`).
- ☐ 🟡 **Provision a prod Upstash Redis** and confirm persistence/eviction
  settings; set memory/eviction alerts (durability — see `docs/compliance.md`).
- ☐ 🟢 Tune the OTP rate-limit constants in `ratelimit.ts` if the load test
  shows venue-login patterns tripping the per-IP caps.

## 2. CI/CD & repo hygiene

- ☐ 🔴 **Add GitHub Actions secrets**: `SUPABASE_ACCESS_TOKEN`,
  `SUPABASE_PROJECT_REF` (per env) for the deploy workflow.
- ☐ 🔴 **Enable branch protection** on `main`: require the `CI` workflow
  (flutter + edge-function + ios-build jobs) to pass before merge.
- ☐ 🟢 Confirm the `ios-build` job goes green on the first macOS run.

## 3. Authentication

- ☐ 🔴 **Configure OTP delivery** in Supabase Auth: a real **SMTP** provider for
  email (built-in SMTP is rate-capped and not for production). If phone OTP is
  used, configure an **SMS provider** and verify coverage for members' regions
  (SMS is region-dependent — prefer email; see `docs/compliance.md`).
- ☐ 🔴 **Live end-to-end OTP test** against a real inbox in staging: request →
  receive → verify → session persists across restart.
- ☐ 🔴 **Live account-deletion test**: delete app login → confirm the auth user
  is gone and the member/attendance records remain.
- ☐ 🟢 **Heartfulness SSO** IdP provisioning (org IT). Swaps in behind the
  `AuthService` seam with no UI change; removes the interim OTP + enumeration
  surface entirely.

## 4. Observability

- ☐ 🟡 **Set `SENTRY_DSN`** (build define) so crashes/errors report; build
  release with `--split-debug-info` so stack traces symbolicate
  (`docs/release.md`).
- ☐ 🟡 Build **Supabase + Upstash dashboards/alerts**: function error rate (from
  the structured logs), DB rows, Redis memory/evictions.

## 5. Reliability / scale

- ☐ 🟡 **Load test** the mass-event path at the 40k–70k target on **staging**
  (`scripts/load-test/attend.js`). Watch the geo-bucket fan-out and the single
  meditation-stop flush; confirm free-tier limits hold or upgrade the Upstash /
  Supabase plans (subscription change, no re-architecting).
- ☐ 🟢 Consider a periodic session checkpoint (cron) if a mid-session Redis loss
  is a concern (the merged flow no longer writes a checkpoint; currently members
  just re-attend in a restarted session).

## 6. Legal / compliance / privacy

- ☐ 🔴 **Fill `docs/privacy.md`** placeholders (controller entity, DPO contact,
  retention periods) and have **Heartfulness legal/DPO review** it.
- ☐ 🔴 **Host the privacy policy** at a public URL; put it in both store listings.
- ☐ 🔴 Complete **Apple App Privacy** + **Google Data safety** forms from the
  privacy.md data table.
- ☐ 🟢 Third-party **penetration test** before public launch (this branch passed
  an internal review; an external pass is best practice).

## 7. Mobile release engineering

### Android
- ☐ 🔴 **Google Play Console** account; create the app (`org.heartfulness.dhyanlog`).
- ☐ 🔴 **Android release keystore** + enrol in **Play App Signing**; build a
  signed app bundle (`docs/release.md`).

### iOS (target is scaffolded + CI compile-checked)
- ☐ 🔴 **Apple Developer account** + a **Mac** (or `macos-latest` CI + App Store
  Connect API key) for signing.
- ☐ 🔴 **App Store Connect** app record for `org.heartfulness.dhyanlog`; set the
  signing Team, then `flutter build ipa` → upload (`docs/release.md`).

### Both
- ☐ 🟡 **App icon + splash** (needs a Heartfulness logo asset — deferred).
- ☐ 🔴 Store listings, screenshots, review notes. Account-deletion path is
  implemented (Apple requirement) — point the reviewer to it.

## 8. Config surface (reference)

Build defines (`--dart-define-from-file`, see `config/README.md`):
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `APP_ENV`.
Function env: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (auto),
`UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`, `ALLOWED_ORIGINS`.

---

## What is already done (no action needed)

Auth + backend role enforcement · server-side OTP (no pre-login PII) · OTP rate
limiting · network resilience + offline queue · observability seams + audit
trail · CI (flutter/deno/iOS) · dark mode + design tokens · full-app i18n
(English, translation-ready) · in-app account deletion · attendee-set
checkpointing · count-only mass-event responses · iOS target scaffolded ·
internal security review passed.
