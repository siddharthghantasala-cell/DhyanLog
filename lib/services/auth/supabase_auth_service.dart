import 'dart:async';

import '../../models/participant.dart';
import '../participant_repository.dart';
import 'auth_service.dart';
import 'auth_session.dart';
import 'contact_mask.dart';
import 'supabase_auth_gateway.dart';

/// Real [AuthService]: interim email/phone OTP via Supabase Auth, with the
/// member identified by their Heartfulness ID. The contact the code is sent to
/// is the email/phone already on the participant record ("on file"); the auth
/// user is linked back to the participant via `heartfulness_id` in user
/// metadata, so the session survives a restart. The per-user JWT it issues is
/// what the [ApiClient] sends so backend calls carry real identity.
///
/// All sign-in logic lives here against the [SupabaseAuthGateway] seam; the
/// Supabase SDK is only touched by `SupabaseAuthGatewayImpl`.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._participants, this._gateway) {
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

  final ParticipantRepository _participants;
  final SupabaseAuthGateway _gateway;
  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();
  StreamSubscription<String?>? _tokenSub;

  AuthSession? _current;
  Participant? _pendingParticipant;
  String? _pendingContact;

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
    final heartfulnessId = session?.heartfulnessId;
    if (session == null || heartfulnessId == null) return null;
    final participant = await _participants.findByHeartfulnessId(heartfulnessId);
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
    final participant = await _participants.findByHeartfulnessId(id);
    if (participant == null) {
      throw AuthException('No Heartfulness member found for "$id".');
    }
    final contact =
        participant.email.isNotEmpty ? participant.email : participant.phone;
    if (contact.isEmpty) {
      throw const AuthException('No email or phone on file for this member.');
    }
    try {
      await _gateway.sendOtp(contact);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Could not send a code. Please try again.');
    }
    _pendingParticipant = participant;
    _pendingContact = contact;
    return OtpChallenge(maskedDestination: maskContact(contact));
  }

  @override
  Future<AuthSession> verifyOtp(String code) async {
    final participant = _pendingParticipant;
    final contact = _pendingContact;
    if (participant == null || contact == null) {
      throw const AuthException('Request a code first.');
    }
    final String token;
    try {
      token = await _gateway.verifyOtp(
        contact: contact,
        token: code.trim(),
        heartfulnessId: participant.heartfulnessId,
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('That code did not work. Please try again.');
    }
    final session = AuthSession(participant: participant, accessToken: token);
    _pendingParticipant = null;
    _pendingContact = null;
    _current = session;
    _controller.add(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await _gateway.signOut();
    _pendingParticipant = null;
    _pendingContact = null;
    _current = null;
    _controller.add(null);
  }

  /// Release the token subscription. (Not called by the app today — the service
  /// is a singleton for the process lifetime — but correct for tests/teardown.)
  void dispose() {
    _tokenSub?.cancel();
    _controller.close();
  }
}
