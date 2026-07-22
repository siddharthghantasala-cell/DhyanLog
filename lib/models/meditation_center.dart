/// A registered meditation center. Used to associate a session with a known
/// location and to help disambiguate GPS matches. Seeded for now.
class MeditationCenter {
  const MeditationCenter({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.checkRadiusMeters = 200,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;

  /// The distance (metres) within which an abhyasi is considered present at this
  /// center's satsang. Owned server-side (the `meditation_centers` table); large
  /// venues (an auditorium ground) run into the kilometres, small halls a few
  /// hundred metres.
  final int checkRadiusMeters;

  factory MeditationCenter.fromJson(Map<String, dynamic> json) {
    return MeditationCenter(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String? ?? '',
      checkRadiusMeters: (json['check_radius_meters'] as num?)?.toInt() ?? 200,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'check_radius_meters': checkRadiusMeters,
    };
  }
}
