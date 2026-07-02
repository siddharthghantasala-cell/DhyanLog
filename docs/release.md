# Release engineering

How DhyanLog goes from a green CI build to the app stores. The pieces marked
**(needs account/secret)** can only be done by someone with the relevant access.

## Environments

Use a **separate Supabase project per environment** (dev / staging / prod) so
staging never touches prod data. Each has its own URL + anon key in
`config/<env>.json` (git-ignored — see `config/README.md`). Promote a change
through staging before prod.

| Env     | Supabase project | `APP_ENV` | Notes                          |
| ------- | ---------------- | --------- | ------------------------------ |
| dev     | dev project      | `dev`     | also the in-memory mock w/ no config |
| staging | staging project  | `staging` | pre-prod verification          |
| prod    | prod project     | `prod`    | the live app                   |

## CI/CD (already wired)

- `.github/workflows/ci.yml` — `flutter analyze` + `flutter test` + `flutter build web`,
  and `deno fmt/check/test` for the edge function, on every PR and push to main.
  **Enable branch protection** on `main` requiring this workflow to pass.
- `.github/workflows/deploy-functions.yml` — deploys the `api` edge function on
  merge to main. **(needs secrets)** `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`.

## Release builds

Always obfuscate release builds and keep the debug symbols (to symbolicate Sentry
crashes):

```sh
flutter build appbundle --dart-define-from-file=config/prod.json \
  --obfuscate --split-debug-info=build/symbols
flutter build ipa --dart-define-from-file=config/prod.json \
  --obfuscate --split-debug-info=build/symbols
```

Bump `version:` in `pubspec.yaml` (`x.y.z+build`) each release.

## Android signing — (needs keystore)

1. Create an upload keystore; store it outside the repo.
2. Add `android/key.properties` (git-ignore it) with the keystore path/passwords.
3. Wire `signingConfigs.release` in `android/app/build.gradle` to read it.
4. Enrol in **Play App Signing**; upload the app bundle to the Play Console.

## iOS — (needs Apple Developer account + macOS)

The `ios/` target **is scaffolded** (bundle id `org.heartfulness.dhyanlog`,
matching Android; `NSLocationWhenInUseUsageDescription` set for the attendance
GPS use). CI compile-checks it on every change via the `ios-build` job
(`macos-latest`, `flutter build ios --no-codesign`) — no Apple account needed to
keep it building.

Remaining, once the Apple Developer account exists (needs macOS + Xcode):

1. Create the App Store Connect app record for `org.heartfulness.dhyanlog`.
2. In Xcode, set the signing **Team** and let it manage provisioning profiles
   (or create them manually).
3. `flutter build ipa` → upload via Transporter / App Store Connect.

Signing can be automated later with a `macos-latest` deploy job using an App
Store Connect API key + Fastlane match (out of scope until the account exists).

## Store submission — (needs store accounts)

- Apple App Store Connect + Google Play Console listings.
- Privacy / data-safety forms (see `docs/privacy.md`).
- Account-deletion path is required by Apple — implemented in-app (see Phase 6).
