import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth/auth_service.dart';
import '../services/http/api_client.dart';
import '../state/providers.dart';

/// A user-safe, plain-language message for any error thrown by the service
/// layer. Keeps raw exception text out of the UI while still distinguishing the
/// cases a user can act on (offline vs. expired session vs. server hiccup).
String messageForError(Object error) {
  if (error is NetworkException) {
    return 'You appear to be offline. Check your connection and try again.';
  }
  if (error is ApiException) {
    if (error.isAuth) return 'Your session has expired. Please sign in again.';
    if (error.isValidation) return error.message; // server message is user-safe
    if (error.isServerError) {
      return 'The server had a problem. Please try again in a moment.';
    }
    return error.message;
  }
  if (error is AuthException) return error.message;
  return 'Something went wrong. Please try again.';
}

/// Whether an error means the caller's session is no longer valid.
bool isAuthError(Object error) => error is ApiException && error.isAuth;

/// Whether an error is worth reporting to telemetry. Offline, expired-session,
/// and validation errors are expected and user-actionable — only server faults
/// (5xx) and unknown errors are unexpected.
bool isUnexpected(Object error) {
  if (error is NetworkException) return false;
  if (error is AuthException) return false;
  if (error is ApiException) return error.isServerError;
  return true;
}

/// Show [error] as a SnackBar and, if it's an expired/invalid session, sign the
/// user out so they return to login. Unexpected errors are also reported to
/// telemetry. Use for one-shot action failures (a tapped button), where the
/// screen otherwise stays put.
void showActionError(WidgetRef ref, BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(messageForError(error))));
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 72, color: scheme.error),
          const SizedBox(height: 16),
          Text(
            messageForError(error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
