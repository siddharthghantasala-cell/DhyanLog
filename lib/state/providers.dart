import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/participant.dart';
import '../services/attendance_service.dart';
import '../services/mock/mock_attendance_service.dart';
import '../services/mock/mock_participant_repository.dart';
import '../services/participant_repository.dart';

/// Swap these two providers for the HTTP-backed implementations in Phase 3 —
/// nothing else in the app changes.
final participantRepositoryProvider = Provider<ParticipantRepository>(
  (ref) => MockParticipantRepository(),
);

final attendanceServiceProvider = Provider<AttendanceService>(
  (ref) => MockAttendanceService(),
);

/// The logged-in participant (null = logged out). Drives routing + theme.
final currentParticipantProvider = StateProvider<Participant?>((ref) => null);
