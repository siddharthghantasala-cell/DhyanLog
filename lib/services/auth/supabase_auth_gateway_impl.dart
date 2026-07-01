import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'supabase_auth_gateway.dart';

/// Real [SupabaseAuthGateway] over the Supabase Auth (GoTrue) client. The OTP
/// exchange happens server-side; this only adopts the resulting session (from
/// its refresh token) and reports/tears it down. The auth user is linked to the
/// participant server-side (metadata written with the service-role key).
class SupabaseAuthGatewayImpl implements SupabaseAuthGateway {
  SupabaseAuthGatewayImpl(this._auth);

  final GoTrueClient _auth;

  @override
  Future<void> setSession(String refreshToken) => _auth.setSession(refreshToken);

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
