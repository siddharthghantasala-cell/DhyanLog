import '../../models/session_history_entry.dart';
import '../http/api_client.dart';
import 'history_service.dart';

/// Real backend history, served by the `sessions/history` route.
class HttpHistoryService implements HistoryService {
  HttpHistoryService(this._api);

  final ApiClient _api;

  @override
  Future<List<SessionHistoryEntry>> myHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _api.post(
      'sessions/history',
      {'limit': limit, 'offset': offset},
      retryable: true, // read-only
    );
    final rows = res['sessions'] as List<dynamic>? ?? const [];
    return rows
        .map((r) => SessionHistoryEntry.fromJson(
              (r as Map).cast<String, dynamic>(),
            ))
        .toList();
  }
}
