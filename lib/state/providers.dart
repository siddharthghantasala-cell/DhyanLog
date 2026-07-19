import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/participant.dart';
import '../services/attendance_service.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/auth_session.dart';
import '../services/auth/http_auth_api.dart';
import '../services/auth/mock_auth_service.dart';
import '../services/auth/supabase_auth_gateway_impl.dart';
import '../services/auth/supabase_auth_service.dart';
import '../services/history/history_service.dart';
import '../services/history/http_history_service.dart';
import '../services/http/api_client.dart';
import '../services/http/http_attendance_service.dart';
import '../services/location/geolocator_location_service.dart';
import '../services/location/location_service.dart';
import '../services/mock/mock_attendance_service.dart';
import '../services/mock/mock_history_service.dart';
import '../services/mock/mock_participant_repository.dart';
import '../services/notifications/android_notification_mute_service.dart';
import '../services/notifications/meditation_mute_controller.dart';
import '../services/notifications/mute_preference.dart';
import '../services/notifications/notification_mute_service.dart';
import '../services/observability/sentry_telemetry.dart';
import '../services/observability/telemetry.dart';
import '../services/offline/attend_queue.dart';
import '../services/offline/prefs_queue_storage.dart';

/// Crash/error reporting seam. Sentry when a DSN is configured (see main.dart),
/// otherwise a no-op — so the app builds and runs with no external service.
final Provider<Telemetry> telemetryProvider = Provider<Telemetry>((ref) {
  return AppConfig.hasSentry ? const SentryTelemetry() : const NoopTelemetry();
});

/// Shared HTTP client for the real backend (only constructed when configured).
/// Sends the signed-in user's JWT when present (read fresh at call time) so
/// backend calls carry real identity, falling back to the anon key pre-login.
// Explicit variable types below break a top-level inference cycle: the client's
// token callback reads authServiceProvider, which (real) reads this client for
// its AuthApi. The cycle is fine at runtime (the callback is lazy).
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    accessToken: () => ref.read(authServiceProvider).currentSession?.accessToken,
  );
});

/// Device-location seam. The real GPS works in both mock and real modes (the
/// home screen's picker decides whether it's used); tests override this with a
/// fake to avoid touching the platform.
final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  if (AppConfig.useRealBackend) {
    return HttpAttendanceService(ref.read(apiClientProvider));
  }
  return MockAttendanceService();
});

/// Read-only history of the member's own past sessions. Split from
/// [attendanceServiceProvider] on purpose — history reads finalized rows and
/// must never touch the live-session hot path.
final historyServiceProvider = Provider<HistoryService>((ref) {
  if (AppConfig.useRealBackend) {
    return HttpHistoryService(ref.read(apiClientProvider));
  }
  // The mock reads the same in-memory store the mock attendance service writes
  // its flushes into, and needs to know whose history to filter for (the real
  // backend takes that from the verified token instead).
  final attendance = ref.read(attendanceServiceProvider);
  final me = ref.watch(currentParticipantProvider);
  return MockHistoryService(
    attendance as MockAttendanceService,
    me?.heartfulnessId ?? '',
  );
});

/// Do Not Disturb seam. Only Android can silence notifications programmatically;
/// iOS exposes no Focus API, so everything else gets the unsupported no-op and
/// the UI degrades to asking the user to enable Focus themselves.
final notificationMuteServiceProvider =
    Provider<NotificationMuteService>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidNotificationMuteService();
  }
  return const UnsupportedNotificationMuteService();
});

final mutePreferenceProvider = Provider<MutePreference>((ref) {
  return MutePreference();
});

/// Owns silence-during-meditation: engages at meditation start, restores at the
/// end, and guards against leaving a phone stranded on silent.
final meditationMuteControllerProvider =
    Provider<MeditationMuteController>((ref) {
  return MeditationMuteController(
    service: ref.read(notificationMuteServiceProvider),
    preference: ref.read(mutePreferenceProvider),
  );
});

/// The user's current "silence my phone while I meditate" setting. A
/// FutureProvider because it is read from disk; invalidated by the settings
/// toggle so watchers refresh.
final muteEnabledProvider = FutureProvider<bool>((ref) {
  return ref.read(mutePreferenceProvider).isEnabled();
});

/// Offline attendance queue: holds attend attempts made while offline and
/// retries them when connectivity returns (safe — attendance is idempotent).
final attendQueueProvider = Provider<AttendQueue>((ref) {
  return AttendQueue(
    ref.read(attendanceServiceProvider),
    PrefsQueueStorage(),
  );
});

/// Authentication seam. Mock identity now; Supabase Auth (interim) then
/// Heartfulness SSO swap in here with no change to the screens, the same way
/// the service providers above swap mock↔real.
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  if (AppConfig.useRealBackend) {
    return SupabaseAuthService(
      HttpAuthApi(ref.read(apiClientProvider)),
      SupabaseAuthGatewayImpl(Supabase.instance.client.auth),
      // Service-role delete of the auth user runs on the edge function, called
      // with the still-valid JWT before sign-out. Not retryable (a delete).
      deleteAccountOnBackend: () =>
          ref.read(apiClientProvider).post('account/delete', const {}),
    );
  }
  return MockAuthService(MockParticipantRepository());
});

/// The live auth session (null = signed out). Screens never set this; sign-in /
/// sign-out flow through [authServiceProvider] and this stream reflects it.
final authStateProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The logged-in participant (null = logged out), derived from the verified
/// session — not free-typed input. Drives routing + theme.
final currentParticipantProvider = Provider<Participant?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.participant;
});
