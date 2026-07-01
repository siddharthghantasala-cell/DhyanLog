import '../../models/participant.dart';

/// The result of a successful server-side OTP verification: the member's own
/// record (safe to hold now that they've proven they control the contact) plus
/// the session tokens minted by Supabase Auth.
class AuthVerification {
  const AuthVerification({
    required this.participant,
    required this.accessToken,
    required this.refreshToken,
  });

  final Participant participant;
  final String accessToken;
  final String refreshToken;
}

/// Seam over the server-side OTP endpoints. Every member email/phone stays on
/// the server: the client sends only a Heartfulness ID and a code, and never
/// receives the raw contact (only a masked hint). This is what removes the old
/// anon-readable PII lookup. Kept abstract so [SupabaseAuthService] can be unit
/// tested with a fake, without a live backend.
abstract class AuthApi {
  /// Ask the server to send a one-time code to the member's contact on file.
  /// Returns a masked hint (e.g. `a***@example.org`) to show the user. Throws
  /// [AuthException] if no member matches or a code couldn't be sent.
  Future<String> requestOtp(String heartfulnessId);

  /// Verify [code] for the member. On success the server returns the session
  /// tokens and the member's own record. Throws [AuthException] on a bad code.
  Future<AuthVerification> verifyOtp(String heartfulnessId, String code);

  /// The caller's own participant, resolved from [accessToken] (used during
  /// session restore, before the app has a current session). Null if not found.
  Future<Participant?> me(String accessToken);
}
