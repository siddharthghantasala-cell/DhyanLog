import 'dart:convert';

import '../../models/attend_result.dart';
import '../../models/pending_attend.dart';
import '../attendance_service.dart';
import '../http/api_client.dart';

/// Persistence seam for the queue (a list of JSON strings). The real impl is
/// backed by SharedPreferences; tests use an in-memory fake.
abstract class QueueStorage {
  Future<List<String>> readAll();
  Future<void> writeAll(List<String> items);
}

/// Holds attendance attempts that failed because the device was offline and
/// retries them when connectivity returns, so a dropped network at a mass event
/// doesn't silently lose attendance. Retry is safe: attendance is idempotent on
/// the server (SADD), so recording a queued item twice is a no-op.
class AttendQueue {
  AttendQueue(this._service, this._storage);

  final AttendanceService _service;
  final QueueStorage _storage;

  Future<List<PendingAttend>> pending() async {
    final raw = await _storage.readAll();
    return raw
        .map((s) => PendingAttend.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> enqueue(PendingAttend item) async {
    final items = await _storage.readAll();
    items.add(jsonEncode(item.toJson()));
    await _storage.writeAll(items);
  }

  Future<void> _save(List<PendingAttend> items) async {
    await _storage.writeAll(items.map((i) => jsonEncode(i.toJson())).toList());
  }

  /// Attempt to record every queued item. Items that reach the server (recorded,
  /// or definitively rejected) are dropped; on the first offline error we stop
  /// and keep the rest for next time. Returns how many were successfully
  /// recorded. Safe to call repeatedly / concurrently-ish (last write wins).
  Future<int> flush() async {
    final items = await pending();
    if (items.isEmpty) return 0;

    var recorded = 0;
    final remaining = <PendingAttend>[];
    var offline = false;

    for (final item in items) {
      if (offline) {
        remaining.add(item); // already lost connectivity; keep the rest
        continue;
      }
      try {
        final result = await _attempt(item);
        if (result.isSuccess) recorded++;
        // Reached the server (success, notFound, or ambiguous) -> drop it.
      } on NetworkException {
        offline = true;
        remaining.add(item);
      } on ApiException {
        // Server responded with an error (e.g. session gone). Not retryable as
        // an offline item -> drop so it doesn't wedge the queue forever.
      }
    }

    await _save(remaining);
    return recorded;
  }

  Future<AttendResult> _attempt(PendingAttend item) {
    if (item.isCoded) {
      return _service.attendByCode(
        heartfulnessId: item.heartfulnessId,
        codeOrSessionId: item.code!,
      );
    }
    return _service.attendByLocation(
      heartfulnessId: item.heartfulnessId,
      latitude: item.latitude!,
      longitude: item.longitude!,
    );
  }
}
