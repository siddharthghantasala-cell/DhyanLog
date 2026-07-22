/// Build-time configuration via --dart-define. When SUPABASE_URL and
/// SUPABASE_ANON_KEY are provided, the app uses the real backend; otherwise it
/// falls back to the in-memory mock (so `flutter run` with no flags still works).
///
/// Example:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get useRealBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get apiBaseUrl => '$supabaseUrl/functions/v1/api';

  /// DEV-ONLY: shared secret matching the backend's `DEV_AUTH_SECRET`. When set
  /// (via --dart-define), sign-in is a single-step Heartfulness-ID login with no
  /// OTP/email — the client sends the id in a header the backend trusts. Empty
  /// (the default) leaves the normal OTP/SSO auth in place. Requires the real
  /// backend to be configured too (so writes still land in the database).
  static const String devAuthSecret = String.fromEnvironment('DEV_AUTH_SECRET');

  static bool get devAuth => devAuthSecret.isNotEmpty && useRealBackend;

  /// Sentry DSN for crash/error reporting. When empty (default), telemetry is a
  /// no-op — the app builds and runs with no external reporting configured.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get hasSentry => sentryDsn.isNotEmpty;

  /// Deploy environment tag attached to telemetry (dev/staging/prod). Defaults
  /// to 'dev' so local runs are distinguishable from real environments.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');
}
