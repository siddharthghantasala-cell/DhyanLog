import 'package:dhyanlog/models/attend_result.dart';
import 'package:dhyanlog/models/meditation_session.dart';
import 'package:dhyanlog/services/mock/mock_attendance_service.dart';
import 'package:dhyanlog/services/mock/seed_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Chennai center coords, reused as the "device" location.
  final chennai = SeedData.centers.firstWhere((c) => c.id == 'CTR-CHN-01');

  group('MockAttendanceService lifecycle', () {
    test('full flow flushes exactly one finalized session at stop', () async {
      final svc = MockAttendanceService();

      final session = await svc.startSession(
        preceptorId: 'HFN-PREC-001',
        centerId: chennai.id,
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );

      // Nothing persisted while the session is hot.
      expect(svc.finalizedSessions, isEmpty);

      for (final id in ['HFN-ABHY-001', 'HFN-ABHY-002', 'HFN-ABHY-003']) {
        final r = await svc.attendByLocation(
          heartfulnessId: id,
          latitude: chennai.latitude,
          longitude: chennai.longitude,
        );
        expect(r.outcome, AttendOutcome.joined);
      }

      await svc.endAttendance(session.id);
      await svc.meditationStart(session.id);

      // Still nothing written until the stop/flush.
      expect(svc.finalizedSessions, isEmpty);

      final done = await svc.meditationStop(session.id);

      expect(svc.finalizedSessions.length, 1);
      expect(done.status, SessionStatus.ended);
      expect(done.attendeeCount, 3);
      expect(done.attendeeIds, containsAll(['HFN-ABHY-001', 'HFN-ABHY-002']));
      expect(done.meditationStartAt, isNotNull);
      expect(done.meditationEndAt, isNotNull);
    });

    test('GPS attendance is idempotent (SADD semantics)', () async {
      final svc = MockAttendanceService();
      await svc.startSession(
        preceptorId: 'HFN-PREC-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );

      final first = await svc.attendByLocation(
        heartfulnessId: 'HFN-ABHY-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      final second = await svc.attendByLocation(
        heartfulnessId: 'HFN-ABHY-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );

      expect(first.outcome, AttendOutcome.joined);
      expect(second.outcome, AttendOutcome.alreadyJoined);
      expect(second.session!.attendeeCount, 1);
    });

    test('two sessions at one location are ambiguous, code disambiguates',
        () async {
      final svc = MockAttendanceService();
      await svc.startSession(
        preceptorId: 'HFN-PREC-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      final b = await svc.startSession(
        preceptorId: 'HFN-PREC-002',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );

      final gps = await svc.attendByLocation(
        heartfulnessId: 'HFN-ABHY-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      expect(gps.outcome, AttendOutcome.ambiguous);
      expect(gps.candidates.length, 2);

      final byCode = await svc.attendByCode(
        heartfulnessId: 'HFN-ABHY-001',
        codeOrSessionId: b.shortCode,
      );
      expect(byCode.outcome, AttendOutcome.joined);
      expect(byCode.session!.id, b.id);
    });

    test('out-of-range attendance is not found', () async {
      final svc = MockAttendanceService();
      await svc.startSession(
        preceptorId: 'HFN-PREC-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      // Paris coords -> far away.
      final r = await svc.attendByLocation(
        heartfulnessId: 'HFN-ABHY-001',
        latitude: 48.8566,
        longitude: 2.3522,
      );
      expect(r.outcome, AttendOutcome.notFound);
    });

    test('attendance closes after End Attendance', () async {
      final svc = MockAttendanceService();
      final s = await svc.startSession(
        preceptorId: 'HFN-PREC-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      await svc.endAttendance(s.id);
      final r = await svc.attendByLocation(
        heartfulnessId: 'HFN-ABHY-001',
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      expect(r.outcome, AttendOutcome.notFound);
    });
  });
}
