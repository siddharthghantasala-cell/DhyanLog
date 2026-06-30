/// Thin seam over the Supabase Auth (GoTrue) calls that [SupabaseAuthService]
/// needs. Keeping it abstract lets the service's linking/state logic be unit
/// tested with a fake, without a live Supabase connection. The real
/// implementation is `SupabaseAuthGatewayImpl` (imports `supabase_flutter`).
abstract class SupabaseAuthGateway {
  /// Send a one-time passcode to [contact] (email or E.164-ish phone).
  Future<void> sendOtp(String contact);

  /// Verify [token] for [contact]; on success persists [heartfulnessId] onto the
  /// auth user (so [currentSession] can re-link after a restart) and returns the
  /// access-token JWT. Throws if verification fails.
  Future<String> verifyOtp({
    required String contact,
    required String token,
    required String heartfulnessId,
  });

  /// The persisted session if one exists: the live access token plus the
  /// `heartfulness_id` stored in user metadata (null if never linked).
  ({String accessToken, String? heartfulnessId})? currentSession();

  /// Emits the latest access token on refresh/sign-in, or null on sign-out
  /// (including sign-out triggered elsewhere). Keeps the session token fresh.
  Stream<String?> accessTokenChanges();

  Future<void> signOut();
}
