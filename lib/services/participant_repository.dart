import '../models/participant.dart';

/// Read-only access to the Heartfulness member database. The mock implementation
/// uses seeded data; the production implementation will adapt the internal
/// Heartfulness DB / SSO. Login looks a participant up by their Heartfulness ID;
/// no record means no entry into the app.
abstract class ParticipantRepository {
  Future<Participant?> findByHeartfulnessId(String heartfulnessId);
}
