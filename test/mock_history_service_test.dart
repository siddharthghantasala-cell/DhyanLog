import 'package:dhyanlog/models/meditation_session.dart';
import 'package:dhyanlog/services/mock/mock_attendance_service.dart';
import 'package:dhyanlog/services/mock/mock_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs a session through its whole lifecycle and returns the finalized record.
Future<MeditationSession> runSession(
  MockAttendanceService service, {
  required String preceptorId,
  required List<String> attendees,
}) async {
  final session = await service.startSession(
    preceptorId: preceptorId,
    centerId: 'CTR-CHN-01',
    latitude: 13.0827,
    longitude: 80.2707,
  );
  for (final id in attendees) {
    await service.attendByCode(
      heartfulnessId: id,
      codeOrSessionId: session.shortCode,
    );
  }
  return service.meditationStop(session.id);
}

void main() {
  group('MockHistoryService', () {
    test('returns a session the member attended', () async {
      final attendance = MockAttendanceService();
      final history =
          MockHistoryService(attendance, 'HFN-ABHY-001', seed: false);

      final finalized = await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001', 'HFN-ABHY-002'],
      );

      final entries = await history.myHistory();
      expect(entries, hasLength(1));
      expect(entries.single.session.id, finalized.id);
      expect(entries.single.led, isFalse);
    });

    test('marks sessions the member led', () async {
      final attendance = MockAttendanceService();
      final history =
          MockHistoryService(attendance, 'HFN-PREC-001', seed: false);

      await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001'],
      );

      final entries = await history.myHistory();
      expect(entries.single.led, isTrue);
    });

    test('excludes sessions the member had nothing to do with', () async {
      final attendance = MockAttendanceService();
      final history =
          MockHistoryService(attendance, 'HFN-ABHY-003', seed: false);

      await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001', 'HFN-ABHY-002'],
      );

      expect(await history.myHistory(), isEmpty);
    });

    test('carries the meditation duration', () async {
      final attendance = MockAttendanceService();
      final history =
          MockHistoryService(attendance, 'HFN-ABHY-001', seed: false);

      await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001'],
      );

      expect(await history.myHistory().then((e) => e.single.duration),
          isNotNull);
    });

    test('orders newest first', () async {
      final attendance = MockAttendanceService();
      final history =
          MockHistoryService(attendance, 'HFN-ABHY-001', seed: false);

      final first = await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001'],
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001'],
      );

      final entries = await history.myHistory();
      expect(
        entries.map((e) => e.session.id),
        [second.id, first.id],
      );
    });

    test('pages through results', () async {
      final attendance = MockAttendanceService();
      final history =
          MockHistoryService(attendance, 'HFN-ABHY-001', seed: false);

      for (var i = 0; i < 3; i++) {
        await runSession(
          attendance,
          preceptorId: 'HFN-PREC-001',
          attendees: ['HFN-ABHY-001'],
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(await history.myHistory(limit: 2, offset: 0), hasLength(2));
      expect(await history.myHistory(limit: 2, offset: 2), hasLength(1));
      expect(await history.myHistory(limit: 2, offset: 5), isEmpty);
    });

    test('seeds a demo history so the screen is not empty on first run',
        () async {
      final attendance = MockAttendanceService();
      final history = MockHistoryService(attendance, 'HFN-ABHY-001');

      expect(await history.myHistory(), isNotEmpty);
    });
  });

  group('MockAttendanceService history invariants', () {
    test('keeps attendee identities after the flush', () async {
      final attendance = MockAttendanceService();
      final finalized = await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001', 'HFN-ABHY-002'],
      );

      // The persisted `attendee_ids` equivalent survives eviction from the hot
      // buffer — that is what personal history is derived from.
      expect(
        attendance.attendeesOf(finalized.id),
        {'HFN-ABHY-001', 'HFN-ABHY-002'},
      );
    });

    test('never exposes identities on the session model', () async {
      final attendance = MockAttendanceService();
      final finalized = await runSession(
        attendance,
        preceptorId: 'HFN-PREC-001',
        attendees: ['HFN-ABHY-001', 'HFN-ABHY-002'],
      );

      expect(finalized.attendeeCount, 2);
      expect(finalized.toJson().containsKey('attendee_ids'), isFalse);
    });
  });
}
