import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// An error response from the edge function (HTTP status >= 400).
class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  /// The caller's token is missing/expired or lacks the required role.
  bool get isAuth => statusCode == 401 || statusCode == 403;

  /// The request was rejected as invalid (won't succeed on retry).
  bool get isValidation => statusCode == 400 || statusCode == 422;

  /// A server-side failure — transient, so safe to retry.
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The server could not be reached at all (offline, DNS, connection reset) or
/// did not answer in time. Distinct from [ApiException], which carries a real
/// HTTP status. Always transient.
class NetworkException implements Exception {
  NetworkException([this.message = 'Could not reach the server.']);
  final String message;
  @override
  String toString() => 'NetworkException: $message';
}

/// Thin POST helper for the routed `api` edge function. Adds a per-request
/// timeout, typed errors, and opt-in retry with exponential backoff + jitter
/// for transient failures. Sends the signed-in user's JWT when available (read
/// fresh at call time), falling back to the anon key before login.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.anonKey,
    String? Function()? accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
    Future<void> Function(Duration)? sleep,
    Random? random,
  })  : _accessToken = accessToken,
        _client = client ?? http.Client(),
        _sleep = sleep ?? Future.delayed,
        _random = random ?? Random();

  final String baseUrl;
  final String anonKey;
  final Duration timeout;

  /// Extra attempts for retryable calls (so maxRetries=2 -> up to 3 tries).
  final int maxRetries;

  final String? Function()? _accessToken;
  final http.Client _client;
  final Future<void> Function(Duration) _sleep;
  final Random _random;

  /// POST [body] to [route]. Set [retryable] only for idempotent operations
  /// (reads and the SADD-idempotent attend) — mutations like session start/stop
  /// must not auto-retry, since a retry after a succeeded-but-timed-out request
  /// would double-create or report a false failure.
  ///
  /// Throws [ApiException] on an HTTP error response, [NetworkException] when
  /// the server is unreachable or times out.
  Future<Map<String, dynamic>> post(
    String route,
    Map<String, dynamic> body, {
    bool retryable = false,
  }) async {
    final maxAttempts = retryable ? maxRetries + 1 : 1;
    for (var attempt = 0;; attempt++) {
      try {
        return await _send(route, body);
      } on ApiException catch (e) {
        final canRetry = attempt + 1 < maxAttempts && e.isServerError;
        if (!canRetry) rethrow;
      } on NetworkException {
        if (attempt + 1 >= maxAttempts) rethrow;
      }
      await _backoff(attempt);
    }
  }

  Future<Map<String, dynamic>> _send(
    String route,
    Map<String, dynamic> body,
  ) async {
    final bearer = _accessToken?.call() ?? anonKey;
    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$baseUrl/$route'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $bearer',
              'apikey': anonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw NetworkException('The request timed out.');
    } on http.ClientException {
      // package:http wraps SocketException/HttpException here on all platforms.
      throw NetworkException();
    }

    final decoded = resp.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw ApiException(
        decoded['error']?.toString() ?? 'HTTP ${resp.statusCode}',
        resp.statusCode,
      );
    }
    return decoded;
  }

  /// Exponential backoff (200ms, 400ms, 800ms, ...) plus up to 100ms jitter to
  /// avoid a thundering herd when many clients fail at once.
  Future<void> _backoff(int attempt) async {
    final base = 200 * (1 << attempt);
    await _sleep(Duration(milliseconds: base + _random.nextInt(100)));
  }
}
