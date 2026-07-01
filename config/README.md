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
| `SUPABASE_URL`       | Project URL. Empty ⇒ app runs on the in-memory mock backend.  |
| `SUPABASE_ANON_KEY`  | Anon key (safe to ship; guarded by RLS + the edge function).  |
| `SENTRY_DSN`         | Crash/error reporting. Empty ⇒ telemetry is a no-op.          |
| `APP_ENV`            | `dev` / `staging` / `prod` — tags telemetry.                  |

Use a **separate Supabase project per environment** so staging never touches
prod data. The backend-only `ALLOWED_ORIGINS` (CORS) is set as a Supabase
function secret, not here:

```sh
supabase secrets set ALLOWED_ORIGINS="https://app.heartfulness.org"
```

In CI/CD, keep these values in GitHub Actions secrets and generate the JSON at
build time — never commit real keys.
