import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'auth_service.dart' show AuthException;
import 'supabase_auth_gateway.dart';

/// Real [SupabaseAuthGateway] over the Supabase Auth (GoTrue) client. Branches
/// email vs phone by the presence of '@'; phone numbers are stripped of spaces
/// toward E.164. The auth user is linked to the participant by writing
/// `heartfulness_id` into user metadata on verify.
class SupabaseAuthGatewayImpl implements SupabaseAuthGateway {
  SupabaseAuthGatewayImpl(this._auth);

  final GoTrueClient _auth;

  bool _isEmail(String contact) => contact.contains('@');

  String _normalize(String contact) =>
      _isEmail(contact) ? contact.trim() : contact.replaceAll(RegExp(r'\s'), '');

  @override
  Future<void> sendOtp(String contact) {
    final c = _normalize(contact);
    return _isEmail(c)
        ? _auth.signInWithOtp(email: c)
        : _auth.signInWithOtp(phone: c);
  }

  @override
  Future<String> verifyOtp({
    required String contact,
    required String token,
    required String heartfulnessId,
  }) async {
    final c = _normalize(contact);
    final isEmail = _isEmail(c);
    final res = await _auth.verifyOTP(
      email: isEmail ? c : null,
      phone: isEmail ? null : c,
      token: token,
      type: isEmail ? OtpType.email : OtpType.sms,
    );
    final session = res.session;
    if (session == null) {
      throw const AuthException('Could not verify the code.');
    }
    // Link the auth user to the Heartfulness member for future restores.
    await _auth.updateUser(
      UserAttributes(data: {'heartfulness_id': heartfulnessId}),
    );
    return session.accessToken;
  }

  @override
  ({String accessToken, String? heartfulnessId})? currentSession() {
    final session = _auth.currentSession;
    if (session == null) return null;
    final heartfulnessId =
        _auth.currentUser?.userMetadata?['heartfulness_id'] as String?;
    return (accessToken: session.accessToken, heartfulnessId: heartfulnessId);
  }

  @override
  Stream<String?> accessTokenChanges() =>
      _auth.onAuthStateChange.map((state) => state.session?.accessToken);

  @override
  Future<void> signOut() => _auth.signOut();
}
