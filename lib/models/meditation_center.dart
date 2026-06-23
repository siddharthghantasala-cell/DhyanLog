/// A registered meditation center. Used to associate a session with a known
/// location and to help disambiguate GPS matches. Seeded for now.
class MeditationCenter {
  const MeditationCenter({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;

  factory MeditationCenter.fromJson(Map<String, dynamic> json) {
    return MeditationCenter(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
}
