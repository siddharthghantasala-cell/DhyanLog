import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/participant.dart';
import '../services/attendance_service.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/auth_session.dart';
import '../services/auth/mock_auth_service.dart';
import '../services/auth/supabase_auth_gateway_impl.dart';
import '../services/auth/supabase_auth_service.dart';
import '../services/http/api_client.dart';
import '../services/http/http_attendance_service.dart';
import '../services/http/http_participant_repository.dart';
import '../services/mock/mock_attendance_service.dart';
import '../services/mock/mock_participant_repository.dart';
import '../services/participant_repository.dart';

/// Shared HTTP client for the real backend (only constructed when configured).
/// Sends the signed-in user's JWT when present (read fresh at call time) so
/// backend calls carry real identity, falling back to the anon key pre-login.
// Explicit variable types below break a top-level inference cycle: the client's
// token callback reads authServiceProvider, which (real) reads the repository,
// which reads this client. The cycle is fine at runtime (the callback is lazy).
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    accessToken: () => ref.read(authServiceProvider).currentSession?.accessToken,
  );
});

/// Real backend when SUPABASE_* dart-defines are set, mock otherwise. This is
/// the single swap point between Phase 2 (mock) and Phase 3 (real).
final Provider<ParticipantRepository> participantRepositoryProvider =
    Provider<ParticipantRepository>((ref) {
  if (AppConfig.useRealBackend) {
    return HttpParticipantRepository(ref.read(apiClientProvider));
  }
  return MockParticipantRepository();
});

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  if (AppConfig.useRealBackend) {
    return HttpAttendanceService(ref.read(apiClientProvider));
  }
  return MockAttendanceService();
});

/// Authentication seam. Mock identity now; Supabase Auth (interim) then
/// Heartfulness SSO swap in here with no change to the screens, the same way
/// the service providers above swap mock↔real.
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  if (AppConfig.useRealBackend) {
    return SupabaseAuthService(
      ref.read(participantRepositoryProvider),
      SupabaseAuthGatewayImpl(Supabase.instance.client.auth),
    );
  }
  return MockAuthService(ref.read(participantRepositoryProvider));
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
