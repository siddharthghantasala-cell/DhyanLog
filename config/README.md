# Environment config

Per-environment build settings, passed to Flutter with `--dart-define-from-file`
instead of long `--dart-define` command lines.

`example.json` is the tracked template. Copy it to `dev.json`, `staging.json`,
and `prod.json` (all git-ignored — they hold real keys) and fill in each
environment's values:

```sh
cp config/example.json config/dev.json   # then edit
flutter run --dart-define-from-file=config/dev.json
flutter build apk --dart-define-from-file=config/prod.json
```

| Key                  | Purpose                                                        |
| -------------------- | ------------------------------------------------------------- |
| `SUPABASE_URL`       | Project URL. Defaulted in `app_config.dart`; override per env. |
| `SUPABASE_ANON_KEY`  | Anon key (safe to ship; guarded by RLS + the edge function).  |
| `DEV_AUTH_SECRET`    | Sign-in key for `AUTH_MODE=id`. **Real secret — never commit.**|
| `AUTH_MODE`          | `id` (default, one-step Heartfulness ID) or `otp` (dormant).   |
| `SENTRY_DSN`         | Crash/error reporting. Empty ⇒ telemetry is a no-op.          |
| `APP_ENV`            | `dev` / `staging` / `prod` — tags telemetry.                  |

`SUPABASE_URL` and `SUPABASE_ANON_KEY` have committed defaults so that a build
made **any** way — the build scripts, a bare `flutter build appbundle`, Android
Studio's signed-bundle dialog — talks to the real database. They used to be
required dart-defines, and a build that omitted them silently downgraded to fake
local data; that reached Play Store internal testing more than once.

`DEV_AUTH_SECRET` is deliberately *not* defaulted: this repo is public, and a
committed value would let anyone sign in as any member. An `AUTH_MODE=id` build
without it shows a "this build can't sign in" screen rather than a login form
that cannot work.

Use a **separate Supabase project per environment** so staging never touches
prod data. The backend-only `ALLOWED_ORIGINS` (CORS) is set as a Supabase
function secret, not here:

```sh
supabase secrets set ALLOWED_ORIGINS="https://app.heartfulness.org"
```

In CI/CD, keep these values in GitHub Actions secrets and generate the JSON at
build time — never commit real keys.
