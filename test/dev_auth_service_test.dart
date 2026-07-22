import 'dart:convert';

import 'package:dhyanlog/models/participant.dart';
import 'package:dhyanlog/services/auth/auth_service.dart';
import 'package:dhyanlog/services/auth/dev_auth_service.dart';
import 'package:dhyanlog/services/http/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds an [ApiClient] whose dev header mirrors what providers wire in prod:
/// it stamps the current sign-in's Heartfulness ID (read fresh) into x-dev-hid.
ApiClient devClient(MockClient mock, DevAuthService Function() service) {
  return ApiClient(
    baseUrl: 'https://x.test/functions/v1/api',
    anonKey: 'anon-key',
    client: mock,
    extraHeaders: () {
      final hid = service().devHeartfulnessId;
      return {
        'x-dev-secret': 'test-secret',
        if (hid != null) 'x-dev-hid': hid,
      };
    },
  );
}

const _meeraJson = {
  'heartfulness_id': 'HFN-ABHY-001',
  'name': 'Meera Nair',
  'age': 29,
  'address': '45 Jasmine Rd, Chennai',
  'email': 'meera@example.org',
  'phone': '+91 90000 33333',
  'role': 'abhyasi',
};

void main() {
  test('signInWithId resolves the member and exposes the session', () async {
    late DevAuthService service;
    final api = devClient(
      MockClient((_) async => http.Response(
            jsonEncode({'participant': _meeraJson}),
            200,
          )),
      () => service,
    );
    service = DevAuthService(api);

    final session = await service.signInWithId('HFN-ABHY-001');
    expect(session.participant.heartfulnessId, 'HFN-ABHY-001');
    expect(session.participant.role, ParticipantRole.abhyasi);
    expect(service.currentSession, isNotNull);
  });

  test('sends the Heartfulness ID in the dev header on the sign-in call',
      () async {
    late http.Request seen;
    late DevAuthService service;
    final api = devClient(
      MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'participant': _meeraJson}), 200);
      }),
      () => service,
    );
    service = DevAuthService(api);

    await service.signInWithId('HFN-ABHY-001');
    // The id must be attached to the very call that resolves it.
    expect(seen.headers['x-dev-hid'], 'HFN-ABHY-001');
    expect(seen.headers['x-dev-secret'], 'test-secret');
    expect(seen.url.path, endsWith('/auth/me'));
  });

  test('an empty id is rejected without a network call', () async {
    var called = false;
    late DevAuthService service;
    final api = devClient(
      MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
      () => service,
    );
    service = DevAuthService(api);

    await expectLater(
      service.signInWithId('  '),
      throwsA(isA<AuthException>()),
    );
    expect(called, isFalse);
  });

  test('an unknown id surfaces as an AuthException and leaves no session',
      () async {
    late DevAuthService service;
    final api = devClient(
      MockClient((_) async => http.Response(
            jsonEncode({'error': 'not a recognized member'}),
            403,
          )),
      () => service,
    );
    service = DevAuthService(api);

    await expectLater(
      service.signInWithId('HFN-NOPE'),
      throwsA(isA<AuthException>()),
    );
    expect(service.currentSession, isNull);
    expect(service.devHeartfulnessId, isNull); // cleared so no stale header
  });

  test('signOut clears the session and the dev header', () async {
    late DevAuthService service;
    final api = devClient(
      MockClient((_) async => http.Response(
            jsonEncode({'participant': _meeraJson}),
            200,
          )),
      () => service,
    );
    service = DevAuthService(api);

    await service.signInWithId('HFN-ABHY-001');
    await service.signOut();
    expect(service.currentSession, isNull);
    expect(service.devHeartfulnessId, isNull);
  });
}
