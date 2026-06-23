import 'meditation_session.dart';

/// Outcome of an abhyasi's attempt to "give attendance".
enum AttendOutcome {
  /// Successfully joined the matched session.
  joined,

  /// Already in the attendee set (idempotent re-tap).
  alreadyJoined,

  /// GPS matched more than one active session — caller must fall back to
  /// QR scan / short code to disambiguate. [candidates] lists the options.
  ambiguous,

  /// No active session matched (out of range / none nearby / bad code).
  notFound,
}

class AttendResult {
  const AttendResult({
    required this.outcome,
    this.session,
    this.candidates = const [],
  });

  final AttendOutcome outcome;

  /// The joined session, set when outcome is [joined] or [alreadyJoined].
  final MeditationSession? session;

  /// Candidate sessions when outcome is [ambiguous].
  final List<MeditationSession> candidates;

  bool get isSuccess =>
      outcome == AttendOutcome.joined || outcome == AttendOutcome.alreadyJoined;

  bool get needsFallback => outcome == AttendOutcome.ambiguous;
}
