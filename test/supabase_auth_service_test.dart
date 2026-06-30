import 'dart:async';

import 'package:dhyanlog/services/auth/auth_service.dart';
import 'package:dhyanlog/services/auth/supabase_auth_gateway.dart';
import 'package:dhyanlog/services/auth/supabase_auth_service.dart';
import 'package:dhyanlog/services/mock/mock_participant_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [SupabaseAuthGateway] standing in for Supabase Auth, so the
/// service's linking + state logic is tested without a live connection.
class FakeGateway implements SupabaseAuthGateway {
  String? sentTo;
  String? linkedHeartfulnessId;
  bool failVerify = false;
  String issuedToken = 'jwt-token-1';
  ({String accessToken, String? heartfulnessId})? session;

  final StreamController<String?> _tokens = StreamController<String?>.broadcast();

  void emitToken(String? token) => _tokens.add(token);

  @override
  Future<void> sendOtp(String contact) async {
    sentTo = contact;
  }

  @override
  Future<String> verifyOtp({
    required String contact,
    required String token,
    required String heartfulnessId,
  }) async {
    if (failVerify) throw Exception('bad code');
    linkedHeartfulnessId = heartfulnessId;
    session = (accessToken: issuedToken, heartfulnessId: heartfulnessId);
    return issuedToken;
  }

  @override
  ({String accessToken, String? heartfulnessId})? currentSession() => session;

  @override
  Stream<String?> accessTokenChanges() => _tokens.stream;

  @override
  Future<void> signOut() async {
    session = null;
  }
}

void main() {
  late MockParticipantRepository repo;
  late FakeGateway gateway;
  late SupabaseAuthService auth;

  setUp(() {
    repo = MockParticipantRepository();
    gateway = FakeGateway();
    auth = SupabaseAuthService(repo, gateway);
  });

  tearDown(() => auth.dispose());

  group('SupabaseAuthService.requestOtp', () {
    test('sends the OTP to the email on file and masks it', () async {
      final challenge = await auth.requestOtp('HFN-PREC-001');
      expect(gateway.sentTo, 'asha.rao@example.org');
      expect(challenge.maskedDestination, 'a***@example.org');
      expect(auth.currentSession, isNull);
    });

    test('unknown member throws and sends nothing', () async {
      await expectLater(
        auth.requestOtp('HFN-NOPE-999'),
        throwsA(isA<AuthException>()),
      );
      expect(gateway.sentTo, isNull);
    });
  });

  group('SupabaseAuthService.verifyOtp', () {
    test('verify before request throws', () async {
      await expectLater(
        auth.verifyOtp('123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('success issues a session with the JWT and links the member', () async {
      await auth.requestOtp('HFN-PREC-001');
      final session = await auth.verifyOtp('123456');

      expect(session.participant.heartfulnessId, 'HFN-PREC-001');
      expect(session.accessToken, 'jwt-token-1');
      expect(gateway.linkedHeartfulnessId, 'HFN-PREC-001'); // metadata link
      expect(auth.currentSession, isNotNull);
    });

    test('gateway failure surfaces as a friendly AuthException', () async {
      await auth.requestOtp('HFN-PREC-001');
      gateway.failVerify = true;
      await expectLater(
        auth.verifyOtp('000000'),
        throwsA(isA<AuthException>()),
      );
      expect(auth.currentSession, isNull);
    });
  });

  group('SupabaseAuthService.restoreSession', () {
    test('rebuilds the session from a persisted auth user', () async {
      gateway.session =
          (accessToken: 'persisted-jwt', heartfulnessId: 'HFN-ABHY-001');
      final restored = await auth.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.participant.heartfulnessId, 'HFN-ABHY-001');
      expect(restored.accessToken, 'persisted-jwt');
    });

    test('returns null when the auth user was never linked', () async {
      gateway.session = (accessToken: 'persisted-jwt', heartfulnessId: null);
      expect(await auth.restoreSession(), isNull);
    });

    test('returns null with no persisted session', () async {
      expect(await auth.restoreSession(), isNull);
    });
  });

  test('a token refresh updates the live session token', () async {
    await auth.requestOtp('HFN-PREC-001');
    await auth.verifyOtp('123456');
    expect(auth.currentSession!.accessToken, 'jwt-token-1');

    gateway.emitToken('jwt-token-2');
    await Future<void>.delayed(Duration.zero); // let the listener run

    expect(auth.currentSession!.accessToken, 'jwt-token-2');
  });

  test('signOut clears the session', () async {
    await auth.requestOtp('HFN-PREC-001');
    await auth.verifyOtp('123456');
    await auth.signOut();
    expect(auth.currentSession, isNull);
  });
}
