import 'dart:async';

import '../../models/participant.dart';
import '../http/api_client.dart';
import 'auth_service.dart';
import 'auth_session.dart';

/// DEV-ONLY [AuthService]: one-step sign-in by Heartfulness ID, no OTP, no
/// password, no email. The member types their id; the client sends it to the
/// backend in the `x-dev-hid` header (attached by [ApiClient] via the dev
/// headers wired in providers), and the backend — with `DEV_AUTH_SECRET` set —
/// trusts it and returns the member's record from `auth/me`. Because the write
/// still goes through the edge function, sessions land in the real database.
///
/// This exists to unblock MVP testing; it is selected only when
/// `AppConfig.devAuth` is true. The real OTP/SSO providers are untouched.
class DevAuthService implements AuthService {
  DevAuthService(this._api);

  final ApiClient _api;

  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();

  AuthSession? _current;
  String? _hid;

  @override
  AuthSession? get currentSession => _current;

  /// The id [ApiClient] should stamp into the dev header. Set before the sign-in
  /// call so `auth/me` itself is already identified.
  @override
  String? get devHeartfulnessId => _hid;

  @override
  Stream<AuthSession?> authStateChanges() async* {
    yield _current; // no persistence in dev — always starts signed out
    yield* _controller.stream;
  }

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> signInWithId(String heartfulnessId) async {
    final id = heartfulnessId.trim();
    if (id.isEmpty) {
      throw const AuthException('Enter your Heartfulness ID.');
    }
    // Set the id first so the dev header is attached to this very call.
    _hid = id;
    try {
      final res = await _api.post('auth/me', const {});
      final participant = res['participant'];
      if (participant == null) {
        throw const AuthException('No Heartfulness member found.');
      }
      final session = AuthSession(
        participant:
            Participant.fromJson((participant as Map).cast<String, dynamic>()),
      );
      _current = session;
      _controller.add(session);
      return session;
    } on ApiException catch (e) {
      _hid = null;
      throw AuthException(
        e.statusCode == 401 || e.statusCode == 403
            ? 'No Heartfulness member found for that ID.'
            : e.message,
      );
    } catch (e) {
      _hid = null;
      if (e is AuthException) rethrow;
      throw const AuthException('Could not sign in. Please try again.');
    }
  }

  @override
  Future<OtpChallenge> requestOtp(String heartfulnessId) =>
      throw const AuthException('Use one-step sign-in.');

  @override
  Future<AuthSession> verifyOtp(String code) =>
      throw const AuthException('Use one-step sign-in.');

  @override
  Future<void> signOut() async {
    _hid = null;
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() => signOut();

  void dispose() {
    _controller.close();
  }
}
