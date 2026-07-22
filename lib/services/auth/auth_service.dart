import 'auth_session.dart';

/// Thrown when a sign-in attempt fails (no matching member, bad code, network
/// error). [message] is safe to show to the user.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// The pending one-time-passcode step after [AuthService.requestOtp]: the code
/// has been sent to the member's contact on file. [maskedDestination] is a
/// privacy-safe hint to show the user (e.g. `a***@example.org`).
class OtpChallenge {
  const OtpChallenge({required this.maskedDestination});
  final String maskedDestination;
}

/// The single seam for authentication. The rest of the app never assigns the
/// current user directly; it reacts to [authStateChanges] and reads the session
/// produced here. This is what lets the mock identity, the interim Supabase Auth
/// (email/phone OTP), and the eventual Heartfulness SSO swap in without touching
/// the home/session screens — mirroring the mock↔real swap already used for
/// [AttendanceService] and [ParticipantRepository] in `lib/state/providers.dart`.
abstract class AuthService {
  /// The current session synchronously, or null when signed out.
  AuthSession? get currentSession;

  /// Emits the current session immediately, then on every sign-in/sign-out.
  /// `null` means signed out.
  Stream<AuthSession?> authStateChanges();

  /// Restore a persisted session at startup (Keychain / Android Keystore for the
  /// real providers). Returns the restored session, or null if none. The mock
  /// does not persist, so it returns null.
  Future<AuthSession?> restoreSession();

  /// One-step DEV sign-in by Heartfulness ID — no OTP, no password. Only
  /// [DevAuthService] implements this (behind the `DEV_AUTH_SECRET` flag); the
  /// OTP/SSO providers reject it. Kept off the main flow so production sign-in
  /// stays the verified-token path.
  Future<AuthSession> signInWithId(String heartfulnessId) =>
      throw const AuthException('Dev sign-in is not enabled.');

  /// The Heartfulness ID the dev-auth client sends to the backend as its
  /// identity. Null for every non-dev provider (they authorize off a token).
  String? get devHeartfulnessId => null;

  /// Step 1 of sign-in: the member identifies themselves by Heartfulness ID; we
  /// send a one-time passcode to the contact (email/phone) on their participant
  /// record. Returns the [OtpChallenge] to show. Throws [AuthException] if no
  /// member matches or they have no contact on file. Heartfulness SSO will add a
  /// `signInWithSso` entry point instead; the lifecycle methods above stay the
  /// stable seam.
  Future<OtpChallenge> requestOtp(String heartfulnessId);

  /// Step 2 of sign-in: verify the [code] the member received. On success a
  /// session is produced and broadcast on [authStateChanges]. Throws
  /// [AuthException] on a wrong/expired code or if no challenge is pending.
  Future<AuthSession> verifyOtp(String code);

  /// End the session and clear any persisted tokens.
  Future<void> signOut();

  /// Permanently delete the app login (the Supabase Auth account) and sign out.
  /// The member's org record and historical attendance are org-owned data and
  /// are deliberately left intact. Satisfies the app stores' in-app
  /// account-deletion requirement. Throws [AuthException] if the deletion could
  /// not be completed (the caller should keep the user signed in in that case).
  Future<void> deleteAccount();
}
