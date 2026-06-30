import '../../models/participant.dart';

/// A verified, signed-in session: the authenticated [participant] plus the
/// bearer token (if any) used to authorize backend calls on their behalf.
///
/// The mock provider issues sessions with a null [accessToken] (no real
/// identity proof); the Supabase Auth / Heartfulness SSO providers will carry a
/// per-user JWT here, which the [ApiClient] sends instead of the bare anon key.
class AuthSession {
  const AuthSession({required this.participant, this.accessToken});

  final Participant participant;

  /// Per-user JWT for backend authorization. Null for the mock provider.
  final String? accessToken;
}
