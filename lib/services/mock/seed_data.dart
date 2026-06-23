import '../../models/meditation_center.dart';
import '../../models/participant.dart';

/// Stand-in for the internal Heartfulness database. These are the records the
/// real `ParticipantRepository` will eventually pull from the live system.
///
/// Heartfulness IDs here use a readable `HFN-...` form for testing; the real
/// system uses UUIDs, but the contract treats the id as an opaque string.
class SeedData {
  static const List<Participant> participants = [
    Participant(
      heartfulnessId: 'HFN-PREC-001',
      name: 'Asha Rao',
      age: 52,
      address: '12 Lotus St, Chennai',
      email: 'asha.rao@example.org',
      phone: '+91 90000 11111',
      role: ParticipantRole.preceptor,
    ),
    Participant(
      heartfulnessId: 'HFN-PREC-002',
      name: 'Daniel Mertens',
      age: 47,
      address: '8 Rue du Calme, Paris',
      email: 'daniel.m@example.org',
      phone: '+33 6 00 00 22 22',
      role: ParticipantRole.preceptor,
    ),
    Participant(
      heartfulnessId: 'HFN-MASTER-000',
      name: 'Revered Master',
      age: 70,
      address: 'Kanha Shanti Vanam, Hyderabad',
      email: 'master@example.org',
      phone: '+91 90000 00000',
      role: ParticipantRole.master,
    ),
    Participant(
      heartfulnessId: 'HFN-ABHY-001',
      name: 'Meera Nair',
      age: 29,
      address: '45 Jasmine Rd, Chennai',
      email: 'meera.n@example.org',
      phone: '+91 90000 33333',
      role: ParticipantRole.abhyasi,
    ),
    Participant(
      heartfulnessId: 'HFN-ABHY-002',
      name: 'Carlos Mendez',
      age: 34,
      address: '20 Calle Sol, Madrid',
      email: 'carlos.m@example.org',
      phone: '+34 600 44 44 44',
      role: ParticipantRole.abhyasi,
    ),
    Participant(
      heartfulnessId: 'HFN-ABHY-003',
      name: 'Yuki Tanaka',
      age: 41,
      address: '3 Sakura Ave, Kyoto',
      email: 'yuki.t@example.org',
      phone: '+81 90 0000 5555',
      role: ParticipantRole.abhyasi,
    ),
  ];

  static const List<MeditationCenter> centers = [
    MeditationCenter(
      id: 'CTR-CHN-01',
      name: 'Chennai Heartfulness Center',
      latitude: 13.0827,
      longitude: 80.2707,
      address: 'Chennai, Tamil Nadu',
    ),
    MeditationCenter(
      id: 'CTR-PAR-01',
      name: 'Paris Meditation Hall',
      latitude: 48.8566,
      longitude: 2.3522,
      address: 'Paris, France',
    ),
    MeditationCenter(
      id: 'CTR-KANHA',
      name: 'Kanha Shanti Vanam',
      latitude: 17.1860,
      longitude: 78.2050,
      address: 'Hyderabad, Telangana',
    ),
  ];
}
