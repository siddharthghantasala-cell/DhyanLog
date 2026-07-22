import '../../models/meditation_center.dart';
import '../mock/seed_data.dart';
import 'centers_service.dart';

/// Returns the seeded centers (which carry placeholder check radii), matching
/// what the real backend serves from the `meditation_centers` table.
class MockCentersService implements CentersService {
  @override
  Future<List<MeditationCenter>> listCenters() async => SeedData.centers;
}
