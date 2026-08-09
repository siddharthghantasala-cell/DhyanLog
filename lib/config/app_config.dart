/// Build-time configuration via --dart-define, with the backend baked in as the
/// default so no build can silently ship against the in-memory mock.
///
/// The project URL and anon key are deliberately committed: the anon key is
/// public by design (it ships in every Supabase client and is guarded by RLS +
/// the edge function), and defaulting them here means an .aab built any way at
/// all — the build scripts, `flutter build appbundle`, Android Studio's signed
/// bundle dialog — talks to the real database. A missing --dart-define used to
/// downgrade the app to fake local data without failing the build, which reached
/// Play Store internal testing more than once.
///
/// Per-environment overrides still work:
///   flutter build apk --dart-define-from-file=config/staging.json
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://iagixzmgvhufnpeyfssq.supabase.co',
  );

  /// Anon key — safe to ship (see `config/README.md`); not a secret.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhZ2l4em1ndmh1Zm5wZXlmc3NxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzMjgxNTcsImV4cCI6MjA5NjkwNDE1N30.TSXc7CUen_tUfEXiprf4GjEKDatgz_iu4o6YM-HxC5U',
  );

  /// False only if a build explicitly blanks the two values above; the mock
  /// backend is otherwise unreachable.
  static bool get useRealBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get apiBaseUrl => '$supabaseUrl/functions/v1/api';

  /// Which sign-in flow this build ships.
  ///
  /// `id` (the default) is the one-step Heartfulness-ID login every member uses
  /// today. `otp` selects the one-time-code flow, which stays wired behind the
  /// [AuthService] seam for the eventual move to verified identity but is not
  /// reachable in a normal build. See `RED_FLAGS.md` #2.
  static const String authMode =
      String.fromEnvironment('AUTH_MODE', defaultValue: 'id');

  static bool get useIdSignIn => authMode != 'otp';

  /// Shared secret matching the backend's `DEV_AUTH_SECRET`, which the id
  /// sign-in client sends in a header the edge function trusts.
  ///
  /// Deliberately NOT defaulted in source, unlike the values above: this repo is
  /// public, and a committed value would let anyone — not just someone holding
  /// the build — sign in as any member (`RED_FLAGS.md` #1). It comes from the
  /// gitignored `config/dev.json` or the build scripts' --dart-define.
  static const String devAuthSecret = String.fromEnvironment('DEV_AUTH_SECRET');

  /// Whether this build can actually sign anyone in. False means an id-sign-in
  /// build was made without [devAuthSecret]; the app refuses to show a login
  /// form it knows cannot work rather than failing at the first tap.
  static bool get isSignInConfigured => !useIdSignIn || devAuthSecret.isNotEmpty;

  static bool get devAuth =>
      useIdSignIn && devAuthSecret.isNotEmpty && useRealBackend;

  /// Sentry DSN for crash/error reporting. When empty (default), telemetry is a
  /// no-op — the app builds and runs with no external reporting configured.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get hasSentry => sentryDsn.isNotEmpty;

  /// Deploy environment tag attached to telemetry (dev/staging/prod). Defaults
  /// to 'dev' so local runs are distinguishable from real environments.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');
}
