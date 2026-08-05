import '../../models/attend_result.dart';
import '../../models/attendee_roster.dart';
import '../../models/meditation_session.dart';
import '../attendance_service.dart';
import 'api_client.dart';

/// Real backend client. Mirrors the edge-function routes. Live updates are done
/// by polling `sessions/get` (Realtime broadcast is a future refinement).
class HttpAttendanceService implements AttendanceService {
  HttpAttendanceService(
    this._api, {
    this.pollInterval = const Duration(seconds: 2),
  });

  final ApiClient _api;
  final Duration pollInterval;

  MeditationSession _session(Map<String, dynamic> json) =>
      MeditationSession.fromJson(json);

  @override
  Future<MeditationSession> startSession({
    required String preceptorId,
    String? centerId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.post('sessions/start', {
      'preceptorId': preceptorId,
      'centerId': centerId,
      'latitude': latitude,
      'longitude': longitude,
    });
    return _session(res);
  }

  @override
  Future<AttendResult> attendByLocation({
    required String heartfulnessId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.post(
      'attend',
      {
        'heartfulnessId': heartfulnessId,
        'latitude': latitude,
        'longitude': longitude,
      },
      retryable: true, // idempotent (SADD)
    );
    return _attendResult(res);
  }

  @override
  Future<AttendResult> attendByCode({
    required String heartfulnessId,
    required String codeOrSessionId,
  }) async {
    final res = await _api.post(
      'attend',
      {
        'heartfulnessId': heartfulnessId,
        'code': codeOrSessionId,
      },
      retryable: true, // idempotent (SADD)
    );
    return _attendResult(res);
  }

  @override
  Future<MeditationSession> meditationStop(String sessionId) async {
    final res =
        await _api.post('sessions/meditation-stop', {'sessionId': sessionId});
    return _session(res);
  }

  @override
  Future<MeditationSession?> getSession(String sessionId) async {
    try {
      final res = await _api.post(
        'sessions/get',
        {'sessionId': sessionId},
        retryable: true, // read-only
      );
      return _session(res);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<AttendeeRoster> sessionRoster(String sessionId) async {
    final res = await _api.post(
      'sessions/attendees',
      {'sessionId': sessionId},
      retryable: true, // read-only
    );
    return AttendeeRoster.fromJson(res);
  }

  @override
  Stream<MeditationSession> watchSession(String sessionId) async* {
    while (true) {
      MeditationSession? session;
      try {
        session = await getSession(sessionId);
      } on NetworkException {
        // Transient: a live session shouldn't die on a momentary drop. Wait and
        // keep polling. (getSession already retried internally first.)
        await Future<void>.delayed(pollInterval);
        continue;
      } on ApiException catch (e) {
        if (e.isServerError) {
          await Future<void>.delayed(pollInterval);
          continue;
        }
        rethrow; // auth/validation errors are not transient — surface them
      }
      if (session == null) break;
      yield session;
      if (session.status == SessionStatus.ended) break;
      await Future<void>.delayed(pollInterval);
    }
  }

  AttendResult _attendResult(Map<String, dynamic> res) {
    final outcome = switch (res['outcome'] as String?) {
      'joined' => AttendOutcome.joined,
      'alreadyJoined' => AttendOutcome.alreadyJoined,
      'ambiguous' => AttendOutcome.ambiguous,
      _ => AttendOutcome.notFound,
    };
    final session = res['session'] == null
        ? null
        : _session((res['session'] as Map).cast<String, dynamic>());
    final candidates = (res['candidates'] as List<dynamic>? ?? const [])
        .map((c) => _session((c as Map).cast<String, dynamic>()))
        .toList();
    return AttendResult(
      outcome: outcome,
      session: session,
      candidates: candidates,
    );
  }
}
