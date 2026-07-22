import '../../models/meditation_center.dart';

/// The registered meditation centers a preceptor can hold a satsang at. Kept a
/// seam (like the other services) so the mock returns seed data and the real
/// impl reads the server-authoritative list — the one place the per-center
/// check radius is owned.
abstract class CentersService {
  Future<List<MeditationCenter>> listCenters();
}
