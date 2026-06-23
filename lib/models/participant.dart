/// A Heartfulness member — either an abhyasi (attendee), a preceptor (session
/// leader), or the master (organization leader). In production these records
/// come from the internal Heartfulness database; for now they are seeded.
///
/// Participants are always referred to by their [heartfulnessId] (a UUID),
/// which is the join key across the whole system.
enum ParticipantRole {
  abhyasi,
  preceptor,
  master;

  static ParticipantRole fromString(String value) {
    return ParticipantRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => ParticipantRole.abhyasi,
    );
  }

  /// Whether this role can start/lead a session.
  bool get canLead => this == preceptor || this == master;
}

class Participant {
  const Participant({
    required this.heartfulnessId,
    required this.name,
    required this.age,
    required this.address,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String heartfulnessId;
  final String name;
  final int age;
  final String address;
  final String email;
  final String phone;
  final ParticipantRole role;

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      heartfulnessId: json['heartfulness_id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      address: json['address'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: ParticipantRole.fromString(json['role'] as String? ?? 'abhyasi'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heartfulness_id': heartfulnessId,
      'name': name,
      'age': age,
      'address': address,
      'email': email,
      'phone': phone,
      'role': role.name,
    };
  }
}
