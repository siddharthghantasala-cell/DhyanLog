# Phase 3 — Deploy & Run the Real Backend

The app talks to a single routed Supabase Edge Function (`api`). The session hot
buffer is Upstash Redis; the only Postgres write is the meditation-stop flush.

The Flutter app auto-selects the backend: if `SUPABASE_URL` + `SUPABASE_ANON_KEY`
are passed as `--dart-define`s it uses the real backend, otherwise the in-memory
mock (so `flutter run` with no flags still works).

---

## Option A — Cloud free tier (no Docker)

### 1. Upstash Redis (free)
1. Create an account at https://upstash.com and a **Redis** database (Global is fine).
2. Copy the **REST URL** and **REST token** from the database's REST API section.

### 2. Supabase (free)
1. Create a project at https://supabase.com. Note the **Project URL** and **anon key**
   (Project Settings → API), and the **service_role key** (kept server-side only).
2. Install the CLI and link:
   ```sh
   npm i -g supabase
   supabase login
   supabase link --project-ref <your-project-ref>
   ```
3. Push schema + seed:
   ```sh
   supabase db push          # applies supabase/migrations
   # seed: run supabase/seed.sql via the SQL editor or:
   psql "$DB_URL" -f supabase/seed.sql
   ```
4. Set the function secrets (Upstash creds; SUPABASE_URL + SERVICE_ROLE are injected
   automatically at runtime):
   ```sh
   supabase secrets set UPSTASH_REDIS_REST_URL=<url> UPSTASH_REDIS_REST_TOKEN=<token>
   ```
5. Deploy the function:
   ```sh
   supabase functions deploy api
   ```

### 3. Run the app against it
```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

---

## Option B — Local stack (Docker)

Requires Docker Desktop running.

```sh
npm i -g supabase
supabase start                 # Postgres + Studio + Edge runtime locally
# migrations apply on start; seed via supabase/seed.sql in Studio SQL editor
```

For the Redis buffer locally, point the function at a local Upstash-compatible
REST shim (e.g. `hiett/serverless-redis-http` + `redis`) and set the same two
env vars. Then serve the function:

```sh
supabase functions serve api --env-file supabase/functions/.env.local
```

`.env.local` (NOT committed):
```
UPSTASH_REDIS_REST_URL=http://localhost:8079
UPSTASH_REDIS_REST_TOKEN=local-dev-token
```

Run the app with the local URL/anon key printed by `supabase start`.

---

## Verify end-to-end
1. Log in as `HFN-PREC-001`, Start Attendance → note the join code, count = 0.
2. From another browser/device, log in as `HFN-ABHY-001`, Give Attendance (GPS or code)
   → the preceptor's count rises (poll-driven).
3. End Attendance → Start Meditation → Stop Meditation.
4. Confirm **exactly one** row in `meditation_sessions` with the attendee array +
   count, and that the Redis keys for the session are gone.

## Monthly analytics job
Run `select expand_attendance();` (e.g. via a scheduled Supabase cron / pg_cron)
to fan out `attendee_ids` into `attendance_expanded` off the hot path.
