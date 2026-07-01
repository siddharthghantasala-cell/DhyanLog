import 'package:sentry_flutter/sentry_flutter.dart';

import 'telemetry.dart';

/// [Telemetry] backed by Sentry. Only constructed when a DSN is configured and
/// `SentryFlutter.init` has run (see `main.dart`). Uses Sentry's static API so
/// it carries no state of its own.
class SentryTelemetry implements Telemetry {
  const SentryTelemetry();

  @override
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, Object?> context = const {},
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        context.forEach((k, v) => scope.setContexts(k, v));
      },
    );
  }

  @override
  void addBreadcrumb(String message, {String? category}) {
    Sentry.addBreadcrumb(Breadcrumb(message: message, category: category));
  }

  @override
  void setUser(String? id) {
    Sentry.configureScope(
      (scope) => scope.setUser(id == null ? null : SentryUser(id: id)),
    );
  }
}
