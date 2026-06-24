# DhyanLog — Future Ventures

Deliberately deferred ideas. Functionality came first (Phases 1–3: contracts, the
Flutter app on a mock backend, then the real Supabase + Upstash backend). This file
captures what comes next so nothing is lost. Nothing here is built yet.

## Accessibility & reach (the core mission)
The app will be used by people across every financial, educational, cultural, and
linguistic background. Ease of use in any language is a first-class goal.

- **Language selection on first launch**, then remembered. Scaffold with
  `flutter_localizations` + `intl`; translate all strings to the major languages
  Heartfulness operates in. (Currently English-only, hardcoded.)
- **Onboarding tutorial** — a short, skippable walkthrough showing the big central
  button and the give/start-attendance flow, shown after language selection.
- **Voice agents** — spoken prompts and voice-driven attendance for low-literacy users
  and hands-free use; text-to-speech for confirmations in the selected language.
- **Large-touch, low-literacy UI** — icon-first, minimal text, high contrast.

## UX polish
- **Per-mode theming** — preceptor vs abhyasi color schemes (partially in place;
  expand into full branded themes, dark mode, logo on the central button).
- **Maps & navigation to meditation centers** — discover nearby centers and route to
  them; tie into the existing `meditation_centers` data.
- **Session history / personal stats** — let an abhyasi see their own attendance and
  streaks.
- **Meditation Animation** — Once meditation starts, the abhyasi's phone also has an 
  animated heartfulness logo on screen until meditation ends.

## App Experience
- **Notifications** — Automatically turning off notifications/setting phone on silent mode once meditation
  starts.
- **Post Meditation Stats** — Once meditation ends, the screen you end up in shows the length
  of meditation, number of attendees and possibly other stats like streak or something of the sort

## Identity & data
- **Real Heartfulness ID SSO** — replace the dummy `participant-lookup` with an adapter
  over the internal Heartfulness member database / SSO. The `ParticipantRepository`
  interface is the single swap point.
- **Per-user auth & RLS** — issue real user JWTs (not just the anon key) so RLS can
  scope reads/writes per participant; restrict who can start sessions to preceptors.
- **PII minimization** — only pull the fields actually needed; audit logging.

## Reliability & scale
- **Offline attendance queueing** — abhyasis in poor-connectivity centers queue their
  "give attendance" locally and sync when back online.
- **Realtime instead of polling** — swap `watchSession`'s 2s poll for Supabase Realtime
  broadcast (or Upstash pub/sub) so the preceptor's count updates push-style.
- **Mass-event tuning (40k–70k+)** — load-test the single flush with very large attendee
  sets; consider chunked attendee storage, Redis sharding by region, and rate limiting.
- **Geo-matching at scale** — the current coarse geo-bucket scan is fine for now;
  evaluate Redis `GEOSEARCH` or a dedicated geo index if active-session density grows.

## Analytics & ML
- **Scheduled expansion** — `expand_attendance()` runs monthly via pg_cron (set up in
  Phase 4) to fan `attendee_ids` into `attendance_expanded` off the hot path.
- **Dashboards** — meditation counts and durations by age, location, and center to find
  where preceptor help is most needed.
- **ML** — classification/regression on the expanded data and running counters
  (e.g., predicting attendance, segmenting centers) once enough history accrues.

## Ops
- **CI** — `flutter analyze` + `flutter test` on every push; preview deploys.
- **Secret management** — move backend creds fully into Supabase secrets / a vault;
  rotate the dev tokens used during bring-up.
- **Monitoring** — function logs, error alerting, Redis/DB usage dashboards to stay
  within free tiers until scale (and funding) arrive.
