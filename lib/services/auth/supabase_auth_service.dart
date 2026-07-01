import 'dart:async';

import 'auth_api.dart';
import 'auth_service.dart';
import 'auth_session.dart';
import 'supabase_auth_gateway.dart';

/// Real [AuthService]: interim OTP sign-in where the member's email/phone stays
/// entirely on the server. The client sends only a Heartfulness ID (step 1) and
/// a code (step 2) through [AuthApi]; the server resolves the contact, sends and
/// verifies the code, links the auth user to the member, and returns session
/// tokens. This service then adopts that session on the [SupabaseAuthGateway]
/// (so the SDK persists it and keeps the token fresh) and exposes the verified
/// participant. Nothing here ever sees the raw contact — only a masked hint.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(
    this._api,
    this._gateway, {
    Future<void> Function()? deleteAccountOnBackend,
  }) : _deleteAccountOnBackend = deleteAccountOnBackend {
    // Keep the session token fresh on refresh, and react to sign-out elsewhere.
    _tokenSub = _gateway.accessTokenChanges().listen((token) {
      if (token == null) {
        if (_current != null) {
          _current = null;
          _controller.add(null);
        }
      } else if (_current != null && _current!.accessToken != token) {
        _current = AuthSession(participant: _current!.participant, accessToken: token);
        _controller.add(_current);
      }
    });
  }

  final AuthApi _api;
  final SupabaseAuthGateway _gateway;

  /// Calls the service-role edge route that deletes the auth user (GoTrue admin
  /// delete can't run client-side). Invoked while the JWT is still valid, before
  /// sign-out. Null in tests / when no backend is wired.
  final Future<void> Function()? _deleteAccountOnBackend;

  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();
  StreamSubscription<String?>? _tokenSub;

  AuthSession? _current;
  String? _pendingId; // Heartfulness ID from requestOtp, awaiting verifyOtp

  @override
  AuthSession? get currentSession => _current;

  @override
  Stream<AuthSession?> authStateChanges() async* {
    // Restore a persisted session on first listen so a returning user lands on
    // home, not login.
    _current ??= await restoreSession();
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final session = _gateway.currentSession();
    if (session == null) return null;
    // Re-fetch the member's own record from the server, authenticated with the
    // just-restored token (the app has no current session to read yet).
    final participant = await _api.me(session.accessToken);
    if (participant == null) return null;
    _current = AuthSession(
      participant: participant,
      accessToken: session.accessToken,
    );
    return _current;
  }

  @override
  Future<OtpChallenge> requestOtp(String heartfulnessId) async {
    final id = heartfulnessId.trim();
    final masked = await _api.requestOtp(id);
    _pendingId = id;
    return OtpChallenge(maskedDestination: masked);
  }

  @override
  Future<AuthSession> verifyOtp(String code) async {
    final id = _pendingId;
    if (id == null) {
      throw const AuthException('Request a code first.');
    }
    final result = await _api.verifyOtp(id, code.trim());
    // Adopt the server-minted session so the SDK persists it and keeps it fresh.
    await _gateway.setSession(result.refreshToken);
    final session = AuthSession(
      participant: result.participant,
      accessToken: result.accessToken,
    );
    _pendingId = null;
    _current = session;
    _controller.add(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await _gateway.signOut();
    _pendingId = null;
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    // Delete the auth user server-side *first*, while the JWT is still valid;
    // only sign out (invalidating the token) once that succeeds. If the backend
    // call fails, surface it and leave the user signed in.
    final delete = _deleteAccountOnBackend;
    if (delete != null) {
      try {
        await delete();
      } on AuthException {
        rethrow;
      } catch (_) {
        throw const AuthException(
          'Could not delete your account. Please try again.',
        );
      }
    }
    await signOut();
  }

  /// Release the token subscription. (Not called by the app today — the service
  /// is a singleton for the process lifetime — but correct for tests/teardown.)
  void dispose() {
    _tokenSub?.cancel();
    _controller.close();
  }
}
