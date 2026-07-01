import 'package:dhyanlog/models/attend_result.dart';
import 'package:dhyanlog/services/attendance_service.dart';
import 'package:dhyanlog/services/auth/auth_service.dart';
import 'package:dhyanlog/services/http/api_client.dart';
import 'package:dhyanlog/services/mock/seed_data.dart';
import 'package:dhyanlog/state/providers.dart';
import 'package:dhyanlog/ui/abhyasi_attend_screen.dart';
import 'package:dhyanlog/ui/error_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AttendanceService whose attend calls fail with a given error; everything else
/// is unused in these tests.
class _FailingAttendance implements AttendanceService {
  _FailingAttendance(this.error);
  final Object error;

  @override
  Future<AttendResult> attendByLocation({
    required String heartfulnessId,
    required double latitude,
    required double longitude,
  }) async =>
      throw error;

  @override
  Future<AttendResult> attendByCode({
    required String heartfulnessId,
    required String codeOrSessionId,
  }) async =>
      throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('messageForError', () {
    test('network error reads as offline', () {
      expect(messageForError(NetworkException()), contains('offline'));
    });

    test('401 reads as an expired session', () {
      expect(
        messageForError(ApiException('x', 401)),
        contains('session has expired'),
      );
      expect(isAuthError(ApiException('x', 401)), isTrue);
    });

    test('validation error passes the server message through', () {
      expect(messageForError(ApiException('invalid centerId', 400)),
          'invalid centerId');
    });

    test('server error is a generic try-again', () {
      expect(messageForError(ApiException('x', 503)), contains('try again'));
    });

    test('auth exception uses its own message', () {
      expect(messageForError(const AuthException('Request a code first.')),
          'Request a code first.');
    });

    test('unknown error is a safe fallback', () {
      expect(messageForError(Exception('boom')), contains('went wrong'));
    });
  });

  group('isUnexpected (telemetry gating)', () {
    test('expected errors are not reported', () {
      expect(isUnexpected(NetworkException()), isFalse); // offline
      expect(isUnexpected(const AuthException('x')), isFalse);
      expect(isUnexpected(ApiException('x', 400)), isFalse); // validation
      expect(isUnexpected(ApiException('x', 401)), isFalse); // auth
    });

    test('server faults and unknowns are reported', () {
      expect(isUnexpected(ApiException('x', 500)), isTrue);
      expect(isUnexpected(Exception('boom')), isTrue);
    });
  });

  final abhyasi = SeedData.participants
      .firstWhere((p) => p.heartfulnessId == 'HFN-ABHY-001');

  testWidgets('abhyasi attend shows retry UI on a server error',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentParticipantProvider.overrideWith((ref) => abhyasi),
          attendanceServiceProvider.overrideWith(
            (ref) => _FailingAttendance(ApiException('boom', 500)),
          ),
        ],
        child: const MaterialApp(
          home: AbhyasiAttendScreen(latitude: 13.08, longitude: 80.27),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('abhyasi attend saves offline when the network is down',
      (tester) async {
    SharedPreferences.setMockInitialValues({}); // back the queue storage

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentParticipantProvider.overrideWith((ref) => abhyasi),
          attendanceServiceProvider
              .overrideWith((ref) => _FailingAttendance(NetworkException())),
        ],
        child: const MaterialApp(
          home: AbhyasiAttendScreen(latitude: 13.08, longitude: 80.27),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved offline'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
