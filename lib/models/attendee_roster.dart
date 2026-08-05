/// The list of attendees a preceptor sees for their own live session — the one
/// place a client is shown *who* checked in, not just how many.
///
/// Deliberately bounded to preserve the app's core scaling rule (no client ever
/// receives a growing, unbounded id/name list): only the owning leader may fetch
/// it, and names are returned only while the set is small enough to stream
/// cheaply. Above the server's roster cap — a mass gathering — the names are
/// withheld and [capped] is true; the [count] is always safe to show.
class AttendeeRoster {
  const AttendeeRoster({
    required this.count,
    required this.names,
    required this.capped,
  });

  /// Total checked-in so far (always present, even when [capped]).
  final int count;

  /// Resolved member names, sorted for a stable display. Empty when [capped].
  final List<String> names;

  /// True when the session is too large to list by name (count only).
  final bool capped;

  static const AttendeeRoster empty =
      AttendeeRoster(count: 0, names: <String>[], capped: false);

  factory AttendeeRoster.fromJson(Map<String, dynamic> json) {
    return AttendeeRoster(
      count: (json['count'] as num?)?.toInt() ?? 0,
      names: ((json['names'] as List<dynamic>?) ?? const [])
          .map((n) => n as String)
          .toList(),
      capped: json['capped'] as bool? ?? false,
    );
  }
}
