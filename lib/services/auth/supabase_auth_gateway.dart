/// Thin seam over the Supabase Auth (GoTrue) session lifecycle that
/// [SupabaseAuthService] needs. The OTP send/verify now happen server-side (see
/// [AuthApi]); this gateway only adopts and tracks the resulting session.
/// Keeping it abstract lets the service's state logic be unit tested with a
/// fake. The real implementation is `SupabaseAuthGatewayImpl`.
abstract class SupabaseAuthGateway {
  /// Adopt the session produced by a server-side verify, from its refresh token.
  /// The SDK then persists it (Keychain / Android Keystore) and keeps it fresh,
  /// so it survives a restart.
  Future<void> setSession(String refreshToken);

  /// The persisted session if one exists: the live access token plus the
  /// `heartfulness_id` stored in user metadata (null if never linked).
  ({String accessToken, String? heartfulnessId})? currentSession();

  /// Emits the latest access token on refresh/sign-in, or null on sign-out
  /// (including sign-out triggered elsewhere). Keeps the session token fresh.
  Stream<String?> accessTokenChanges();

  Future<void> signOut();
}
