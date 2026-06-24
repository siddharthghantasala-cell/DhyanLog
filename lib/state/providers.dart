import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/participant.dart';
import '../services/attendance_service.dart';
import '../services/http/api_client.dart';
import '../services/http/http_attendance_service.dart';
import '../services/http/http_participant_repository.dart';
import '../services/mock/mock_attendance_service.dart';
import '../services/mock/mock_participant_repository.dart';
import '../services/participant_repository.dart';

/// Shared HTTP client for the real backend (only constructed when configured).
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
});

/// Real backend when SUPABASE_* dart-defines are set, mock otherwise. This is
/// the single swap point between Phase 2 (mock) and Phase 3 (real).
final participantRepositoryProvider = Provider<ParticipantRepository>((ref) {
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

/// The logged-in participant (null = logged out). Drives routing + theme.
final currentParticipantProvider = StateProvider<Participant?>((ref) => null);
