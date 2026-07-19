import '../../models/meditation_session.dart';
import '../../models/session_history_entry.dart';
import '../history/history_service.dart';
import 'mock_attendance_service.dart';
import 'seed_data.dart';

/// History over the mock's finalized-session store — the in-memory equivalent of
/// the `attendee_ids @> ARRAY[me]` query the real backend runs.
///
/// Seeds a handful of past sittings on construction so the history screen is
/// meaningful in demo mode before the user has completed a session in-app.
class MockHistoryService implements HistoryService {
  MockHistoryService(this._attendance, this._heartfulnessId, {bool seed = true}) {
    if (seed) _seedPastSessions();
  }

  final MockAttendanceService _attendance;

  /// Whose history this returns. The real implementation takes this from the
  /// verified token instead; here it's injected at construction.
  final String _heartfulnessId;

  @override
  Future<List<SessionHistoryEntry>> myHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final entries = _attendance.finalizedSessions
        .where((s) =>
            s.preceptorId == _heartfulnessId ||
            _attendance.attendeesOf(s.id).contains(_heartfulnessId))
        .map((s) => SessionHistoryEntry(
              session: s,
              led: s.preceptorId == _heartfulnessId,
            ))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (offset >= entries.length) return const [];
    return entries.skip(offset).take(limit).toList();
  }

  /// A short, plausible back-history: roughly every other day for a fortnight,
  /// alternating centers, with varying durations and turnouts.
  void _seedPastSessions() {
    final now = DateTime.now();
    const preceptorId = 'HFN-PREC-001';
    const durationsMinutes = [30, 45, 20, 60, 35, 45, 25];
    const attendeeCounts = [12, 34, 8, 57, 19, 41, 23];

    for (var i = 0; i < durationsMinutes.length; i++) {
      final center = SeedData.centers[i % SeedData.centers.length];
      final start = now.subtract(Duration(days: (i + 1) * 2, hours: 3));
      final meditationStart = start.add(const Duration(minutes: 10));
      final session = MeditationSession(
        id: 'seed_hist_$i',
        preceptorId: preceptorId,
        centerId: center.id,
        latitude: center.latitude,
        longitude: center.longitude,
        startAttendanceAt: start,
        meditationStartAt: meditationStart,
        meditationEndAt:
            meditationStart.add(Duration(minutes: durationsMinutes[i])),
        status: SessionStatus.ended,
        attendeeCount: attendeeCounts[i],
        shortCode: 'SEED0$i',
      );
      // Everyone in the seed set attended, so any demo login has a history.
      _attendance.seedFinalizedSession(
        session,
        SeedData.participants.map((p) => p.heartfulnessId).toSet(),
      );
    }
  }
}
