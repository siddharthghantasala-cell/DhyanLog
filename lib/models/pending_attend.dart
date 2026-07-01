/// An attendance attempt that couldn't reach the server (offline) and is held
/// locally to retry. Either a GPS attempt ([latitude]/[longitude]) or a coded
/// one ([code]). Retrying is safe because attendance is idempotent (SADD) on the
/// server, so a queued item recorded twice is a no-op.
class PendingAttend {
  const PendingAttend({
    required this.id,
    required this.heartfulnessId,
    this.latitude,
    this.longitude,
    this.code,
    required this.queuedAt,
  });

  final String id;
  final String heartfulnessId;
  final double? latitude;
  final double? longitude;
  final String? code;
  final DateTime queuedAt;

  bool get isCoded => code != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'heartfulnessId': heartfulnessId,
        'latitude': latitude,
        'longitude': longitude,
        'code': code,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory PendingAttend.fromJson(Map<String, dynamic> json) => PendingAttend(
        id: json['id'] as String,
        heartfulnessId: json['heartfulnessId'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        code: json['code'] as String?,
        queuedAt: DateTime.parse(json['queuedAt'] as String),
      );
}
