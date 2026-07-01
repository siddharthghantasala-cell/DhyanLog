/// The lifecycle status of a session. While `collecting` and `meditating`, the
/// session lives entirely in the hot buffer (Redis in production, in-memory in
/// the mock). Only on transition to `ended` is the single Postgres row written.
enum SessionStatus {
  collecting,
  meditating,
  ended;

  static SessionStatus fromString(String value) {
    return SessionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SessionStatus.collecting,
    );
  }
}

/// A meditation session — this single object is both the live "buffer packet"
/// (while open) and the finalized record (once ended). The attendee *identities*
/// live only in the hot buffer (Redis) and are written once, as an
/// `attendee_ids` array, at the flush; clients only ever need the running
/// [attendeeCount], so this model deliberately carries the count, not the list.
/// (Sending the full list on every attend would be O(n²) at mass-event scale.)
class MeditationSession {
  const MeditationSession({
    required this.id,
    required this.preceptorId,
    required this.centerId,
    required this.latitude,
    required this.longitude,
    required this.startAttendanceAt,
    required this.meditationStartAt,
    required this.meditationEndAt,
    required this.status,
    required this.attendeeCount,
    required this.shortCode,
  });

  final String id;
  final String preceptorId;
  final String? centerId;
  final double latitude;
  final double longitude;
  final DateTime startAttendanceAt;
  final DateTime? meditationStartAt;
  final DateTime? meditationEndAt;
  final SessionStatus status;

  /// Number of de-duplicated attendees so far. The identities themselves are not
  /// sent to clients — only this count.
  final int attendeeCount;

  /// Short human-readable code read out / shown for fallback joins.
  final String shortCode;

  /// Payload encoded into the preceptor's QR code for scan-to-join.
  String get qrPayload => 'dhyanlog://attend?session=$id';

  MeditationSession copyWith({
    DateTime? meditationStartAt,
    DateTime? meditationEndAt,
    SessionStatus? status,
    int? attendeeCount,
  }) {
    return MeditationSession(
      id: id,
      preceptorId: preceptorId,
      centerId: centerId,
      latitude: latitude,
      longitude: longitude,
      startAttendanceAt: startAttendanceAt,
      meditationStartAt: meditationStartAt ?? this.meditationStartAt,
      meditationEndAt: meditationEndAt ?? this.meditationEndAt,
      status: status ?? this.status,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      shortCode: shortCode,
    );
  }

  factory MeditationSession.fromJson(Map<String, dynamic> json) {
    // Prefer the explicit count; fall back to an array length only if a legacy
    // payload still carries `attendee_ids`.
    final count = (json['attendee_count'] as num?)?.toInt() ??
        (json['attendee_ids'] as List<dynamic>?)?.length ??
        0;
    return MeditationSession(
      id: json['id'] as String,
      preceptorId: json['preceptor_id'] as String,
      centerId: json['center_id'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      startAttendanceAt: DateTime.parse(json['start_attendance_at'] as String),
      meditationStartAt: json['meditation_start_at'] == null
          ? null
          : DateTime.parse(json['meditation_start_at'] as String),
      meditationEndAt: json['meditation_end_at'] == null
          ? null
          : DateTime.parse(json['meditation_end_at'] as String),
      status: SessionStatus.fromString(json['status'] as String? ?? 'collecting'),
      attendeeCount: count,
      shortCode: json['short_code'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'preceptor_id': preceptorId,
      'center_id': centerId,
      'latitude': latitude,
      'longitude': longitude,
      'start_attendance_at': startAttendanceAt.toIso8601String(),
      'meditation_start_at': meditationStartAt?.toIso8601String(),
      'meditation_end_at': meditationEndAt?.toIso8601String(),
      'status': status.name,
      'attendee_count': attendeeCount,
      'short_code': shortCode,
    };
  }
}
