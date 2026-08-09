import 'dart:async';

import '../../models/participant.dart';
import '../participant_repository.dart';
import 'auth_service.dart';
import 'auth_session.dart';
import 'contact_mask.dart';

/// In-memory [AuthService] for local dev and widget tests. It mirrors both
/// shipped shapes — one-step sign-in by Heartfulness ID, and the two-step OTP
/// flow, which runs its real shape but doesn't send or check a code (any 6-digit
/// code verifies). Issues sessions with no token (the mock backend doesn't check
/// one). State lives only in memory, so a restart signs the user out
/// (`restoreSession` returns null).
class MockAuthService implements AuthService {
  MockAuthService(this._participants);

  final ParticipantRepository _participants;
  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();

  AuthSession? _current;
  Participant? _pending; // member resolved in requestOtp, awaiting verifyOtp

  @override
  AuthSession? get currentSession => _current;

  @override
  Stream<AuthSession?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<OtpChallenge> requestOtp(String heartfulnessId) async {
    final id = heartfulnessId.trim();
    final participant = await _participants.findByHeartfulnessId(id);
    if (participant == null) {
      throw AuthException('No Heartfulness member found for "$id".');
    }
    final contact = participant.email.isNotEmpty
        ? participant.email
        : participant.phone;
    if (contact.isEmpty) {
      throw const AuthException('No email or phone on file for this member.');
    }
    _pending = participant;
    return OtpChallenge(maskedDestination: maskContact(contact));
  }

  @override
  Future<AuthSession> verifyOtp(String code) async {
    final pending = _pending;
    if (pending == null) {
      throw const AuthException('Request a code first.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const AuthException('Enter the 6-digit code.');
    }
    final session = AuthSession(participant: pending);
    _pending = null;
    _current = session;
    _controller.add(session);
    return session;
  }

  /// The shipping flow's mock: resolve the member and issue a session, with no
  /// code step. Mirrors [DevAuthService] against the seeded participants.
  @override
  Future<AuthSession> signInWithId(String heartfulnessId) async {
    final id = heartfulnessId.trim();
    if (id.isEmpty) {
      throw const AuthException('Enter your Heartfulness ID.');
    }
    final participant = await _participants.findByHeartfulnessId(id);
    if (participant == null) {
      throw AuthException('No Heartfulness member found for "$id".');
    }
    final session = AuthSession(participant: participant);
    _pending = null;
    _current = session;
    _controller.add(session);
    return session;
  }

  @override
  String? get devHeartfulnessId => null;

  @override
  Future<void> signOut() async {
    _pending = null;
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    // No backend in the mock: deleting the login is just signing out.
    await signOut();
  }
}
