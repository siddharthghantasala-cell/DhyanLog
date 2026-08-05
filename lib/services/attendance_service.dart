import '../models/attend_result.dart';
import '../models/attendee_roster.dart';
import '../models/meditation_session.dart';

/// The session lifecycle API. Mirrors the Edge Function endpoints so the mock
/// and the real HTTP implementation are interchangeable behind this type.
///
/// Lifecycle (only two preceptor actions; everything before the stop mutates
/// only the hot buffer):
///   start -> (abhyasis attend, throughout) -> meditationStop
/// A session is *meditating with attendance still open* from the moment it
/// starts, so latecomers are counted for the whole meditation. [meditationStop]
/// is the single flush that persists one finalized session and closes the door.
abstract class AttendanceService {
  /// Preceptor starts the session: attendance opens and meditation begins at the
  /// same instant. Creates the hot session + geo index entry and returns it
  /// (with id, short code, QR payload).
  Future<MeditationSession> startSession({
    required String preceptorId,
    String? centerId,
    required double latitude,
    required double longitude,
  });

  /// Abhyasi gives attendance via GPS. Matches the nearest active session within
  /// radius + time window. May return [AttendOutcome.ambiguous] for the caller to
  /// disambiguate via [attendByCode].
  Future<AttendResult> attendByLocation({
    required String heartfulnessId,
    required double latitude,
    required double longitude,
  });

  /// Abhyasi gives attendance via an explicit short code or session id
  /// (QR-scan / typed-code fallback).
  Future<AttendResult> attendByCode({
    required String heartfulnessId,
    required String codeOrSessionId,
  });

  /// Stamp meditation end and FLUSH: persist exactly one finalized session row,
  /// then evict from the hot buffer. Returns the finalized session.
  Future<MeditationSession> meditationStop(String sessionId);

  /// Current snapshot of a session (from hot buffer while open, else store).
  Future<MeditationSession?> getSession(String sessionId);

  /// The names of attendees who have checked in to a live session, for the
  /// preceptor leading it. The *only* path that shows a client identities rather
  /// than a bare count — and deliberately bounded: only the owning leader may
  /// call it, and only a session below the server's roster cap returns names (a
  /// mass gathering returns the count with [AttendeeRoster.capped] set). Never
  /// streams an unbounded list, so the one-write / count-only scaling rule holds.
  Future<AttendeeRoster> sessionRoster(String sessionId);

  /// Live updates for the preceptor screen (attendee count climbing, status
  /// changes). Backed by Realtime/polling in production.
  Stream<MeditationSession> watchSession(String sessionId);
}
