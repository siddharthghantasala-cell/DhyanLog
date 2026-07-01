import 'package:dhyanlog/services/auth/auth_service.dart';
import 'package:dhyanlog/services/auth/contact_mask.dart';
import 'package:dhyanlog/services/auth/mock_auth_service.dart';
import 'package:dhyanlog/services/mock/mock_participant_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockAuthService OTP flow', () {
    late MockAuthService auth;

    setUp(() => auth = MockAuthService(MockParticipantRepository()));

    test('requestOtp masks the contact on file', () async {
      final challenge = await auth.requestOtp('HFN-PREC-001');
      // Seed email asha.rao@example.org -> a***@example.org
      expect(challenge.maskedDestination, 'a***@example.org');
      expect(auth.currentSession, isNull); // not signed in until verify
    });

    test('requestOtp is trimmed and case-insensitive', () async {
      final challenge = await auth.requestOtp('  hfn-abhy-001 ');
      expect(challenge.maskedDestination, contains('@'));
    });

    test('unknown ID throws AuthException', () async {
      await expectLater(
        auth.requestOtp('HFN-NOPE-999'),
        throwsA(isA<AuthException>()),
      );
    });

    test('verifyOtp before requestOtp throws', () async {
      await expectLater(
        auth.verifyOtp('123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('non-6-digit code is rejected', () async {
      await auth.requestOtp('HFN-PREC-001');
      await expectLater(
        auth.verifyOtp('12'),
        throwsA(isA<AuthException>()),
      );
      expect(auth.currentSession, isNull);
    });

    test('valid code produces a session for the requested member', () async {
      await auth.requestOtp('HFN-PREC-001');
      final session = await auth.verifyOtp('123456');

      expect(session.participant.heartfulnessId, 'HFN-PREC-001');
      expect(session.participant.role.canLead, isTrue);
      expect(session.accessToken, isNull); // mock issues no token
      expect(auth.currentSession, isNotNull);
    });

    test('authStateChanges emits initial null, the session, then null on sign-out',
        () async {
      final emitted = <String?>[];
      final sub = auth
          .authStateChanges()
          .listen((s) => emitted.add(s?.participant.heartfulnessId));

      await auth.requestOtp('HFN-ABHY-002');
      await auth.verifyOtp('000000');
      await auth.signOut();
      await Future<void>.delayed(Duration.zero); // let the stream drain

      expect(emitted, [null, 'HFN-ABHY-002', null]);
      await sub.cancel();
    });

    test('mock does not persist: restoreSession returns null', () async {
      expect(await auth.restoreSession(), isNull);
    });

    test('deleteAccount signs the user out', () async {
      await auth.requestOtp('HFN-PREC-001');
      await auth.verifyOtp('123456');
      expect(auth.currentSession, isNotNull);

      await auth.deleteAccount();
      expect(auth.currentSession, isNull);
    });
  });

  group('maskContact', () {
    test('masks emails to first char + domain', () {
      expect(maskContact('asha.rao@example.org'), 'a***@example.org');
    });

    test('masks phones to last 4 digits', () {
      expect(maskContact('+91 90000 11111'), '***1111');
    });

    test('empty contact is empty', () {
      expect(maskContact('   '), '');
    });
  });
}
