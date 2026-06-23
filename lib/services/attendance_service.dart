import '../models/attend_result.dart';
import '../models/meditation_session.dart';

/// The session lifecycle API. Mirrors the planned Edge Function endpoints so the
/// mock and the real HTTP implementation are interchangeable behind this type.
///
/// Lifecycle (all steps before [meditationStop] mutate only the hot buffer):
///   start -> (abhyasis attend) -> endAttendance -> meditationStart -> meditationStop
/// [meditationStop] is the single flush that persists one finalized session.
abstract class AttendanceService {
  /// Preceptor starts an attendance window. Creates the hot session + geo index
  /// entry and returns it (with id, short code, QR payload).
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

  /// Freeze the attendee set (status collecting -> still collecting, no more
  /// joins). Hot-buffer only; no DB write.
  Future<MeditationSession> endAttendance(String sessionId);

  /// Stamp meditation start. Hot-buffer only; no DB write.
  Future<MeditationSession> meditationStart(String sessionId);

  /// Stamp meditation end and FLUSH: persist exactly one finalized session row,
  /// then evict from the hot buffer. Returns the finalized session.
  Future<MeditationSession> meditationStop(String sessionId);

  /// Current snapshot of a session (from hot buffer while open, else store).
  Future<MeditationSession?> getSession(String sessionId);

  /// Live updates for the preceptor screen (attendee count climbing, status
  /// changes). Backed by Realtime/polling in production.
  Stream<MeditationSession> watchSession(String sessionId);
}
