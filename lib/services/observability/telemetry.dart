/// App-wide telemetry seam: crash/error reporting + breadcrumbs, decoupled from
/// any specific vendor. The default [NoopTelemetry] does nothing (so the app
/// builds and tests run with no external service); [SentryTelemetry] forwards to
/// Sentry when a DSN is configured. Mirrors the mock↔real seam used elsewhere.
abstract class Telemetry {
  /// Report a handled-but-unexpected error (e.g. a 5xx or an unknown failure).
  /// Expected, user-actionable errors (offline, validation) should NOT be sent.
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, Object?> context,
  });

  /// Leave a trail of recent actions to give a captured error context.
  void addBreadcrumb(String message, {String? category});

  /// Tag the current user on subsequent events (id only — never PII).
  void setUser(String? id);
}

class NoopTelemetry implements Telemetry {
  const NoopTelemetry();

  @override
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, Object?> context = const {},
  }) async {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void setUser(String? id) {}
}
