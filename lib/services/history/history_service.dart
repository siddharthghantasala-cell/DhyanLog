import '../../models/session_history_entry.dart';

/// Read-only access to the signed-in member's own past meditations.
///
/// Deliberately a separate seam from [AttendanceService]: that type is the live
/// session lifecycle (hot-buffer writes), whereas this only ever reads finalized
/// rows. Keeping them apart stops history queries from creeping into the
/// mass-event hot path.
///
/// Scope is always "me". There is no parameter for whose history to fetch —
/// the backend derives identity from the verified token — so a client cannot
/// ask for someone else's record.
abstract class HistoryService {
  /// Past sessions, newest first. Paged: request [limit] entries starting at
  /// [offset]. An empty result means there are no more.
  Future<List<SessionHistoryEntry>> myHistory({int limit, int offset});
}
