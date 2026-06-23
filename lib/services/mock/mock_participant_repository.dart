import '../../models/participant.dart';
import '../participant_repository.dart';
import 'seed_data.dart';

/// In-memory [ParticipantRepository] backed by [SeedData]. Lookups are
/// case-insensitive and trimmed to be forgiving of manual ID entry.
class MockParticipantRepository implements ParticipantRepository {
  MockParticipantRepository({List<Participant>? participants})
      : _byId = {
          for (final p in (participants ?? SeedData.participants))
            p.heartfulnessId.toUpperCase(): p,
        };

  final Map<String, Participant> _byId;

  @override
  Future<Participant?> findByHeartfulnessId(String heartfulnessId) async {
    // Simulate a tiny bit of network latency so loading states are exercised.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _byId[heartfulnessId.trim().toUpperCase()];
  }
}
