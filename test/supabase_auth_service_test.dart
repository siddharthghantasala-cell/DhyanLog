import 'dart:async';

import 'package:dhyanlog/models/participant.dart';
import 'package:dhyanlog/services/auth/auth_api.dart';
import 'package:dhyanlog/services/auth/auth_service.dart';
import 'package:dhyanlog/services/auth/supabase_auth_gateway.dart';
import 'package:dhyanlog/services/auth/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _member = Participant(
  heartfulnessId: 'HFN-PREC-001',
  name: 'Asha Rao',
  age: 40,
  address: '',
  email: 'asha.rao@example.org',
  phone: '',
  role: ParticipantRole.preceptor,
);

/// In-memory [AuthApi] standing in for the server-side OTP endpoints.
class FakeAuthApi implements AuthApi {
  String? requestedId;
  bool failRequest = false;
  bool failVerify = false;
  Participant? meResult; // what restore's me() returns

  @override
  Future<String> requestOtp(String heartfulnessId) async {
    if (failRequest) throw const AuthException('No Heartfulness member found.');
    requestedId = heartfulnessId;
    return 'a***@example.org';
  }

  @override
  Future<AuthVerification> verifyOtp(String heartfulnessId, String code) async {
    if (failVerify) throw const AuthException('That code did not work.');
    return const AuthVerification(
      participant: _member,
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
  }

  @override
  Future<Participant?> me(String accessToken) async => meResult;
}

/// In-memory [SupabaseAuthGateway]: tracks the adopted session + token stream.
class FakeGateway implements SupabaseAuthGateway {
  String? adoptedRefreshToken;
  ({String accessToken, String? heartfulnessId})? session;

  final StreamController<String?> _tokens = StreamController<String?>.broadcast();
  void emitToken(String? token) => _tokens.add(token);

  @override
  Future<void> setSession(String refreshToken) async {
    adoptedRefreshToken = refreshToken;
    session = (accessToken: 'access-1', heartfulnessId: 'HFN-PREC-001');
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
  late FakeAuthApi api;
  late FakeGateway gateway;
  late SupabaseAuthService auth;

  setUp(() {
    api = FakeAuthApi();
    gateway = FakeGateway();
    auth = SupabaseAuthService(api, gateway);
  });

  tearDown(() => auth.dispose());

  group('requestOtp', () {
    test('returns the masked hint and remembers the id, no session yet', () async {
      final challenge = await auth.requestOtp('  HFN-PREC-001 ');
      expect(api.requestedId, 'HFN-PREC-001'); // trimmed
      expect(challenge.maskedDestination, 'a***@example.org');
      expect(auth.currentSession, isNull);
    });

    test('a server rejection surfaces as AuthException', () async {
      api.failRequest = true;
      await expectLater(
        auth.requestOtp('HFN-NOPE-999'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('verifyOtp', () {
    test('verify before request throws', () async {
      await expectLater(
        auth.verifyOtp('123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('success adopts the session and exposes the member', () async {
      await auth.requestOtp('HFN-PREC-001');
      final session = await auth.verifyOtp('123456');

      expect(session.participant.heartfulnessId, 'HFN-PREC-001');
      expect(session.accessToken, 'access-1');
      expect(gateway.adoptedRefreshToken, 'refresh-1'); // session adopted
      expect(auth.currentSession, isNotNull);
    });

    test('a bad code surfaces as AuthException and leaves no session', () async {
      await auth.requestOtp('HFN-PREC-001');
      api.failVerify = true;
      await expectLater(
        auth.verifyOtp('000000'),
        throwsA(isA<AuthException>()),
      );
      expect(auth.currentSession, isNull);
    });
  });

  group('restoreSession', () {
    test('rebuilds the session by fetching me() with the restored token', () async {
      gateway.session = (accessToken: 'persisted', heartfulnessId: 'HFN-PREC-001');
      api.meResult = _member;
      final restored = await auth.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.participant.heartfulnessId, 'HFN-PREC-001');
      expect(restored.accessToken, 'persisted');
    });

    test('returns null when there is no persisted session', () async {
      expect(await auth.restoreSession(), isNull);
    });

    test('returns null when me() no longer resolves the member', () async {
      gateway.session = (accessToken: 'persisted', heartfulnessId: 'HFN-PREC-001');
      api.meResult = null;
      expect(await auth.restoreSession(), isNull);
    });
  });

  test('a token refresh updates the live session token', () async {
    await auth.requestOtp('HFN-PREC-001');
    await auth.verifyOtp('123456');
    expect(auth.currentSession!.accessToken, 'access-1');

    gateway.emitToken('access-2');
    await Future<void>.delayed(Duration.zero); // let the listener run

    expect(auth.currentSession!.accessToken, 'access-2');
  });

  test('signOut clears the session', () async {
    await auth.requestOtp('HFN-PREC-001');
    await auth.verifyOtp('123456');
    await auth.signOut();
    expect(auth.currentSession, isNull);
  });

  group('deleteAccount', () {
    test('calls the backend then signs out', () async {
      var backendCalled = false;
      final withDelete = SupabaseAuthService(
        api,
        gateway,
        deleteAccountOnBackend: () async {
          backendCalled = true;
        },
      );
      addTearDown(withDelete.dispose);

      await withDelete.requestOtp('HFN-PREC-001');
      await withDelete.verifyOtp('123456');
      await withDelete.deleteAccount();

      expect(backendCalled, isTrue);
      expect(withDelete.currentSession, isNull);
      expect(gateway.session, isNull); // gateway signed out too
    });

    test('backend failure surfaces as AuthException and keeps the session',
        () async {
      final withDelete = SupabaseAuthService(
        api,
        gateway,
        deleteAccountOnBackend: () async => throw Exception('500'),
      );
      addTearDown(withDelete.dispose);

      await withDelete.requestOtp('HFN-PREC-001');
      await withDelete.verifyOtp('123456');

      await expectLater(
        withDelete.deleteAccount(),
        throwsA(isA<AuthException>()),
      );
      expect(withDelete.currentSession, isNotNull); // still signed in
    });
  });
}
