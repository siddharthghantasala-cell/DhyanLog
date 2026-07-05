import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/auth/auth_service.dart';
import '../services/http/api_client.dart';
import '../services/location/location_service.dart';
import '../state/providers.dart';

/// A user-safe, plain-language message for any error thrown by the service
/// layer. Keeps raw exception text out of the UI while still distinguishing the
/// cases a user can act on (offline vs. expired session vs. server hiccup).
/// Messages that originate on the server (validation / auth) are already
/// user-safe and are passed through unlocalized.
String messageForError(AppLocalizations l10n, Object error) {
  if (error is NetworkException) {
    return l10n.errorOffline;
  }
  if (error is ApiException) {
    if (error.isAuth) return l10n.errorSessionExpired;
    if (error.isValidation) return error.message; // server message is user-safe
    if (error.isServerError) {
      return l10n.errorServer;
    }
    return error.message;
  }
  if (error is AuthException) return error.message;
  if (error is LocationException) {
    return switch (error.failure) {
      LocationFailure.servicesDisabled => l10n.errorLocationOff,
      LocationFailure.permissionDenied => l10n.errorLocationDenied,
      LocationFailure.permissionDeniedForever => l10n.errorLocationBlocked,
      LocationFailure.timeout => l10n.errorLocationTimeout,
    };
  }
  return l10n.commonSomethingWrong;
}

/// Whether an error means the caller's session is no longer valid.
bool isAuthError(Object error) => error is ApiException && error.isAuth;

/// Whether an error is worth reporting to telemetry. Offline, expired-session,
/// and validation errors are expected and user-actionable — only server faults
/// (5xx) and unknown errors are unexpected.
bool isUnexpected(Object error) {
  if (error is NetworkException) return false;
  if (error is AuthException) return false;
  if (error is LocationException) return false; // user-actionable

  if (error is ApiException) return error.isServerError;
  return true;
}

/// Show [error] as a SnackBar and, if it's an expired/invalid session, sign the
/// user out so they return to login. Unexpected errors are also reported to
/// telemetry. Use for one-shot action failures (a tapped button), where the
/// screen otherwise stays put.
void showActionError(WidgetRef ref, BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(messageForError(l10n, error))));
  if (isAuthError(error)) {
    ref.read(authServiceProvider).signOut();
  }
  if (isUnexpected(error)) {
    ref.read(telemetryProvider).captureError(error, StackTrace.current).ignore();
  }
}

/// A reusable inline error block with a retry button, for screens whose whole
/// body failed to load.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 72, color: scheme.error),
          const SizedBox(height: 16),
          Text(
            messageForError(l10n, error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.commonTryAgain),
          ),
        ],
      ),
    );
  }
}
