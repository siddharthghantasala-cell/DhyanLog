import '../../models/meditation_center.dart';
import '../http/api_client.dart';
import 'centers_service.dart';

/// Reads the center list (with each center's check radius) from the edge
/// function. Read-only, so it's safe to retry on a transient failure.
class HttpCentersService implements CentersService {
  HttpCentersService(this._api);

  final ApiClient _api;

  @override
  Future<List<MeditationCenter>> listCenters() async {
    final res = await _api.post('centers/list', const {}, retryable: true);
    final list = res['centers'] as List<dynamic>? ?? const [];
    return list
        .map((c) =>
            MeditationCenter.fromJson((c as Map).cast<String, dynamic>()))
        .toList();
  }
}
