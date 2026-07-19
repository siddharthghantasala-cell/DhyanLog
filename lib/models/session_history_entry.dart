import 'meditation_session.dart';

/// One row in a member's personal meditation history.
///
/// Wraps the finalized [MeditationSession] rather than replacing it, so history
/// stays a *view over* the single session record — there is no parallel history
/// model that could drift from it.
class SessionHistoryEntry {
  const SessionHistoryEntry({required this.session, required this.led});

  final MeditationSession session;

  /// True when the member led this session rather than (only) attending it.
  final bool led;

  /// When the sitting happened — meditation start where recorded, else the
  /// opening of the attendance window.
  DateTime get occurredAt =>
      session.meditationStartAt ?? session.startAttendanceAt;

  /// How long the meditation ran, or null if it was never stamped.
  Duration? get duration {
    final start = session.meditationStartAt;
    final end = session.meditationEndAt;
    if (start == null || end == null) return null;
    final d = end.difference(start);
    return d.isNegative ? null : d;
  }

  factory SessionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SessionHistoryEntry(
      session: MeditationSession.fromJson(json),
      led: json['led'] as bool? ?? false,
    );
  }
}
