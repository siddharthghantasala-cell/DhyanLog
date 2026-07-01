import 'dart:convert';
import 'dart:math';

import 'package:dhyanlog/services/http/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient clientWith(
  MockClient mock, {
  String? Function()? accessToken,
  Duration timeout = const Duration(seconds: 15),
}) {
  return ApiClient(
    baseUrl: 'https://x.test/functions/v1/api',
    anonKey: 'anon-key',
    accessToken: accessToken,
    client: mock,
    timeout: timeout,
    sleep: (_) async {}, // no real backoff delay in tests
    random: Random(1),
  );
}

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  test('returns the decoded body on success', () async {
    final api = clientWith(MockClient((_) async => jsonResponse({'ok': true})));
    expect(await api.post('participant-lookup', {}), {'ok': true});
  });

  test('empty response body decodes to an empty map', () async {
    final api = clientWith(MockClient((_) async => http.Response('', 200)));
    expect(await api.post('sessions/get', {}), <String, dynamic>{});
  });

  test('sends the user JWT as bearer, anon key as apikey', () async {
    late http.Request seen;
    final api = clientWith(
      MockClient((req) async {
        seen = req;
        return jsonResponse({});
      }),
      accessToken: () => 'user-jwt',
    );
    await api.post('attend', {});
    expect(seen.headers['authorization'], 'Bearer user-jwt');
    expect(seen.headers['apikey'], 'anon-key');
  });

  test('falls back to the anon key as bearer before login', () async {
    late http.Request seen;
    final api = clientWith(MockClient((req) async {
      seen = req;
      return jsonResponse({});
    }));
    await api.post('participant-lookup', {});
    expect(seen.headers['authorization'], 'Bearer anon-key');
  });

  test('4xx throws a typed ApiException and is never retried', () async {
    var calls = 0;
    final api = clientWith(MockClient((_) async {
      calls++;
      return jsonResponse({'error': 'bad'}, 400);
    }));
    await expectLater(
      api.post('attend', {}, retryable: true),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 400)
          .having((e) => e.isValidation, 'isValidation', true)),
    );
    expect(calls, 1); // 4xx won't change on retry
  });

  test('401 is flagged as an auth error', () async {
    final api = clientWith(
      MockClient((_) async => jsonResponse({'error': 'nope'}, 401)),
    );
    await expectLater(
      api.post('sessions/start', {}),
      throwsA(isA<ApiException>().having((e) => e.isAuth, 'isAuth', true)),
    );
  });

  test('non-retryable 5xx fails after a single attempt', () async {
    var calls = 0;
    final api = clientWith(MockClient((_) async {
      calls++;
      return jsonResponse({'error': 'boom'}, 500);
    }));
    await expectLater(
      api.post('sessions/start', {}), // mutation: retryable defaults to false
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  test('retryable 5xx retries up to maxRetries+1 then throws', () async {
    var calls = 0;
    final api = clientWith(MockClient((_) async {
      calls++;
      return jsonResponse({'error': 'boom'}, 503);
    }));
    await expectLater(
      api.post('sessions/get', {}, retryable: true),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 3); // default maxRetries = 2
  });

  test('retryable call succeeds on a later attempt', () async {
    var calls = 0;
    final api = clientWith(MockClient((_) async {
      calls++;
      if (calls < 2) return jsonResponse({'error': 'boom'}, 500);
      return jsonResponse({'recovered': true});
    }));
    expect(await api.post('attend', {}, retryable: true), {'recovered': true});
    expect(calls, 2);
  });

  test('connection errors become NetworkException and retry when allowed',
      () async {
    var calls = 0;
    final api = clientWith(MockClient((_) async {
      calls++;
      throw http.ClientException('connection reset');
    }));
    await expectLater(
      api.post('sessions/get', {}, retryable: true),
      throwsA(isA<NetworkException>()),
    );
    expect(calls, 3);
  });

  test('connection errors are not retried for mutations', () async {
    var calls = 0;
    final api = clientWith(MockClient((_) async {
      calls++;
      throw http.ClientException('offline');
    }));
    await expectLater(
      api.post('sessions/meditation-stop', {}),
      throwsA(isA<NetworkException>()),
    );
    expect(calls, 1);
  });

  test('a slow response past the timeout becomes a NetworkException', () async {
    final api = clientWith(
      MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return jsonResponse({});
      }),
      timeout: const Duration(milliseconds: 40),
    );
    await expectLater(
      api.post('sessions/get', {}),
      throwsA(isA<NetworkException>()),
    );
  });
}
