import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin POST helper for the routed `api` edge function. Sends the signed-in
/// user's JWT as the bearer token when available (so the function sees real
/// identity), falling back to the anon key before login. The `apikey` header is
/// always the anon key, which Supabase's gateway requires.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.anonKey,
    String? Function()? accessToken,
    http.Client? client,
  })  : _accessToken = accessToken,
        _client = client ?? http.Client();

  final String baseUrl;
  final String anonKey;

  /// Reads the current per-user JWT at call time (null before login). Kept as a
  /// callback so a token refresh is always picked up without rebuilding this.
  final String? Function()? _accessToken;
  final http.Client _client;

  Future<Map<String, dynamic>> post(
    String route,
    Map<String, dynamic> body,
  ) async {
    final bearer = _accessToken?.call() ?? anonKey;
    final resp = await _client.post(
      Uri.parse('$baseUrl/$route'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearer',
        'apikey': anonKey,
      },
      body: jsonEncode(body),
    );
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
}
