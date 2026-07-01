import '../../models/participant.dart';
import '../http/api_client.dart';
import 'auth_api.dart';
import 'auth_service.dart' show AuthException;

/// [AuthApi] over the `auth/*` edge routes. Translates transport errors into
/// friendly [AuthException]s: a 4xx carries a server message safe to show; a
/// network failure or 5xx becomes a generic "try again".
class HttpAuthApi implements AuthApi {
  HttpAuthApi(this._api);

  final ApiClient _api;

  @override
  Future<String> requestOtp(String heartfulnessId) async {
    final res = await _guard(
      () => _api.post('auth/request-otp', {'heartfulnessId': heartfulnessId}),
      'Could not send a code. Please try again.',
    );
    return res['masked'] as String? ?? '';
  }

  @override
  Future<AuthVerification> verifyOtp(String heartfulnessId, String code) async {
    final res = await _guard(
      () => _api.post(
        'auth/verify-otp',
        {'heartfulnessId': heartfulnessId, 'code': code},
      ),
      'That code did not work. Please try again.',
    );
    final participant = res['participant'];
    final accessToken = res['access_token'] as String?;
    final refreshToken = res['refresh_token'] as String?;
    if (participant == null || accessToken == null || refreshToken == null) {
      throw const AuthException('Sign-in failed. Please try again.');
    }
    return AuthVerification(
      participant:
          Participant.fromJson((participant as Map).cast<String, dynamic>()),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<Participant?> me(String accessToken) async {
    // Read-only, and authenticated with the just-restored token explicitly (the
    // app has no current session yet at restore time).
    final res = await _api.post(
      'auth/me',
      const {},
      retryable: true,
      authToken: accessToken,
    );
    final participant = res['participant'];
    if (participant == null) return null;
    return Participant.fromJson((participant as Map).cast<String, dynamic>());
  }

  /// Run an edge call, surfacing a server 4xx message to the user and collapsing
  /// everything else (network, 5xx) into [fallback].
  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() call,
    String fallback,
  ) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.statusCode >= 400 && e.statusCode < 500) {
        throw AuthException(e.message);
      }
      throw AuthException(fallback);
    } catch (_) {
      throw AuthException(fallback);
    }
  }
}
