import 'dart:async';
import 'dart:math';

import '../../models/attend_result.dart';
import '../../models/meditation_center.dart';
import '../../models/meditation_session.dart';
import '../../util/geo.dart';
import '../attendance_service.dart';
import 'seed_data.dart';

/// In-memory stand-in for the Redis buffer + Edge Functions + Postgres flush.
///
/// - [_hot]   : sessions still open (the buffer). Mutated freely, no "writes".
/// - [_store] : finalized sessions (the single Postgres row per session).
/// - [_frozen]: sessions whose attendee set is closed (after end-attendance).
///
/// GPS matching mimics Redis `GEOSEARCH`: active, unfrozen, `collecting`
/// sessions within [matchRadiusMeters] and the time window are candidates.
class MockAttendanceService implements AttendanceService {
  MockAttendanceService({
    this.regularRadiusMeters = 30,
    this.matchWindow = const Duration(hours: 3),
  });

  /// Default capture radius for a regular (home) session — mirrors the backend's
  /// DEFAULT_REGULAR_RADIUS_METERS. A satsang uses its center's radius instead.
  final double regularRadiusMeters;
  final Duration matchWindow;

  final Map<String, MeditationSession> _hot = {};
  final Map<String, MeditationSession> _store = {};
  final Set<String> _frozen = {};
  final Map<String, StreamController<MeditationSession>> _controllers = {};

  /// Attendee identities per session — the stand-in for the Redis attendee set.
  /// Kept here (not on the session model) because clients only ever see counts.
  final Map<String, Set<String>> _attendees = {};

  final Random _rng = Random();

  @override
  Future<MeditationSession> startSession({
    required String preceptorId,
    String? centerId,
    required double latitude,
    required double longitude,
  }) async {
    final id = _generateId();
    // Mirror the backend: a center id -> satsang with that center's radius; no
    // center -> regular with the tight default. (The caller already passes the
    // center's coords as lat/lng for a satsang, so the anchor is correct.)
    final center = centerId == null
        ? null
        : SeedData.centers
            .cast<MeditationCenter?>()
            .firstWhere((c) => c?.id == centerId, orElse: () => null);
    final type = centerId != null ? SessionType.satsang : SessionType.regular;
    final radius = center?.checkRadiusMeters ??
        (centerId != null ? 200 : regularRadiusMeters.round());
    final session = MeditationSession(
      id: id,
      preceptorId: preceptorId,
      centerId: centerId,
      latitude: latitude,
      longitude: longitude,
      startAttendanceAt: DateTime.now(),
      meditationStartAt: null,
      meditationEndAt: null,
      status: SessionStatus.collecting,
      attendeeCount: 0,
      shortCode: _generateCode(),
      type: type,
      matchRadiusMeters: radius,
    );
    _hot[id] = session;
    _attendees[id] = <String>{};
    _controllers[id] = StreamController<MeditationSession>.broadcast();
    return session;
  }

  @override
  Future<AttendResult> attendByLocation({
    required String heartfulnessId,
    required double latitude,
    required double longitude,
  }) async {
    final now = DateTime.now();
    final candidates = _hot.values.where((s) {
      if (_frozen.contains(s.id)) return false;
      if (s.status != SessionStatus.collecting) return false;
      if (now.difference(s.startAttendanceAt) > matchWindow) return false;
      // Each session matches within its own radius (satsang vs regular).
      return distanceMeters(latitude, longitude, s.latitude, s.longitude) <=
          s.matchRadiusMeters.toDouble();
    }).toList();

    if (candidates.isEmpty) {
      return const AttendResult(outcome: AttendOutcome.notFound);
    }
    if (candidates.length > 1) {
      return AttendResult(
        outcome: AttendOutcome.ambiguous,
        candidates: candidates,
      );
    }
    return _join(candidates.single.id, heartfulnessId);
  }

  @override
  Future<AttendResult> attendByCode({
    required String heartfulnessId,
    required String codeOrSessionId,
  }) async {
    final needle = codeOrSessionId.trim().toUpperCase();
    final match = _hot.values.where((s) {
      if (_frozen.contains(s.id)) return false;
      if (s.status != SessionStatus.collecting) return false;
      return s.shortCode.toUpperCase() == needle ||
          s.id.toUpperCase() == needle;
    });
    if (match.isEmpty) {
      return const AttendResult(outcome: AttendOutcome.notFound);
    }
    return _join(match.first.id, heartfulnessId);
  }

  /// SADD-equivalent: add the attendee to the set, idempotently.
  AttendResult _join(String sessionId, String heartfulnessId) {
    final session = _hot[sessionId];
    final attendees = _attendees[sessionId];
    if (session == null || attendees == null) {
      return const AttendResult(outcome: AttendOutcome.notFound);
    }
    if (!attendees.add(heartfulnessId)) {
      return AttendResult(
        outcome: AttendOutcome.alreadyJoined,
        session: session,
      );
    }
    final updated = session.copyWith(attendeeCount: attendees.length);
    _hot[sessionId] = updated;
    _emit(updated);
    return AttendResult(outcome: AttendOutcome.joined, session: updated);
  }

  @override
  Future<MeditationSession> endAttendance(String sessionId) async {
    final session = _requireHot(sessionId);
    _frozen.add(sessionId);
    _emit(session);
    return session;
  }

  @override
  Future<MeditationSession> meditationStart(String sessionId) async {
    final session = _requireHot(sessionId);
    final updated = session.copyWith(
      meditationStartAt: DateTime.now(),
      status: SessionStatus.meditating,
    );
    _hot[sessionId] = updated;
    _emit(updated);
    return updated;
  }

  @override
  Future<MeditationSession> meditationStop(String sessionId) async {
    final session = _requireHot(sessionId);
    // THE single flush: finalize, persist to the store, evict from the buffer.
    final finalized = session.copyWith(
      meditationEndAt: DateTime.now(),
      status: SessionStatus.ended,
    );
    _store[sessionId] = finalized;
    _hot.remove(sessionId);
    _frozen.remove(sessionId);
    // The attendee set is deliberately KEPT after the flush: it is the mock's
    // stand-in for the persisted `attendee_ids` column, which is what personal
    // history is queried from. (Redis evicts; Postgres doesn't.)
    _emit(finalized);
    await _controllers[sessionId]?.close();
    _controllers.remove(sessionId);
    return finalized;
  }

  @override
  Future<MeditationSession?> getSession(String sessionId) async {
    return _hot[sessionId] ?? _store[sessionId];
  }

  @override
  Stream<MeditationSession> watchSession(String sessionId) async* {
    final current = _hot[sessionId] ?? _store[sessionId];
    if (current != null) yield current;
    final controller = _controllers[sessionId];
    if (controller != null) {
      yield* controller.stream;
    }
  }

  /// Finalized sessions — the equivalent of rows in `meditation_sessions`.
  /// Exposed for verification / a future local dashboard.
  List<MeditationSession> get finalizedSessions =>
      List.unmodifiable(_store.values);

  /// The persisted attendee identities of a finalized session — the mock's
  /// `attendee_ids` column. Read by [MockHistoryService]; never surfaced to a
  /// screen, which only ever sees counts.
  Set<String> attendeesOf(String sessionId) =>
      Set.unmodifiable(_attendees[sessionId] ?? const <String>{});

  /// Insert an already-finished session, as if it had been flushed earlier.
  /// Used to seed a believable history in demo/mock mode.
  void seedFinalizedSession(
    MeditationSession session,
    Set<String> attendees,
  ) {
    _store[session.id] = session;
    _attendees[session.id] = {...attendees};
  }

  MeditationSession _requireHot(String sessionId) {
    final session = _hot[sessionId];
    if (session == null) {
      throw StateError('Session $sessionId is not active');
    }
    return session;
  }

  void _emit(MeditationSession session) {
    _controllers[session.id]?.add(session);
  }

  String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = _rng.nextInt(1 << 32).toRadixString(36);
    return 'sess_${ts}_$rand';
  }

  String _generateCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    return List.generate(6, (_) => alphabet[_rng.nextInt(alphabet.length)])
        .join();
  }
}
