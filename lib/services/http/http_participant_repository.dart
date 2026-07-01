import '../../models/participant.dart';
import '../participant_repository.dart';
import 'api_client.dart';

class HttpParticipantRepository implements ParticipantRepository {
  HttpParticipantRepository(this._api);

  final ApiClient _api;

  @override
  Future<Participant?> findByHeartfulnessId(String heartfulnessId) async {
    final res = await _api.post(
      'participant-lookup',
      {'heartfulnessId': heartfulnessId},
      retryable: true, // read-only
    );
    final participant = res['participant'];
    if (participant == null) return null;
    return Participant.fromJson((participant as Map).cast<String, dynamic>());
  }
}
