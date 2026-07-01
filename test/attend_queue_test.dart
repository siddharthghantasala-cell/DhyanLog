import 'package:dhyanlog/models/attend_result.dart';
import 'package:dhyanlog/models/pending_attend.dart';
import 'package:dhyanlog/services/attendance_service.dart';
import 'package:dhyanlog/services/http/api_client.dart';
import 'package:dhyanlog/services/offline/attend_queue.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryQueueStorage implements QueueStorage {
  List<String> items = [];
  @override
  Future<List<String>> readAll() async => List.of(items);
  @override
  Future<void> writeAll(List<String> next) async => items = List.of(next);
}

/// Attendance service that returns scripted outcomes per call (success,
/// notFound, or a thrown error), in order.
class ScriptedAttend implements AttendanceService {
  ScriptedAttend(this._script);
  final List<AttendResult Function()> _script;
  int calls = 0;

  AttendResult _next() => _script[calls++]();

  @override
  Future<AttendResult> attendByLocation({
    required String heartfulnessId,
    required double latitude,
    required double longitude,
  }) async =>
      _next();

  @override
  Future<AttendResult> attendByCode({
    required String heartfulnessId,
    required String codeOrSessionId,
  }) async =>
      _next();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AttendResult joined() => const AttendResult(outcome: AttendOutcome.joined);
AttendResult notFound() => const AttendResult(outcome: AttendOutcome.notFound);
Never offline() => throw NetworkException();
Never serverGone() => throw ApiException('not found', 404);

PendingAttend gps(String id) => PendingAttend(
      id: id,
      heartfulnessId: 'HFN-ABHY-001',
      latitude: 13.08,
      longitude: 80.27,
      queuedAt: DateTime(2026, 6, 30),
    );

void main() {
  test('enqueue then pending round-trips the item', () async {
    final storage = InMemoryQueueStorage();
    final queue = AttendQueue(ScriptedAttend([]), storage);
    await queue.enqueue(gps('a'));

    final pending = await queue.pending();
    expect(pending, hasLength(1));
    expect(pending.single.heartfulnessId, 'HFN-ABHY-001');
    expect(pending.single.latitude, 13.08);
  });

  test('flush records successes and clears them', () async {
    final storage = InMemoryQueueStorage();
    final queue = AttendQueue(ScriptedAttend([joined, joined]), storage);
    await queue.enqueue(gps('a'));
    await queue.enqueue(gps('b'));

    final recorded = await queue.flush();
    expect(recorded, 2);
    expect(await queue.pending(), isEmpty);
  });

  test('flush keeps items when offline and stops early', () async {
    final storage = InMemoryQueueStorage();
    // First succeeds, second goes offline -> third must not be attempted.
    final service = ScriptedAttend([joined, offline]);
    final queue = AttendQueue(service, storage);
    await queue.enqueue(gps('a'));
    await queue.enqueue(gps('b'));
    await queue.enqueue(gps('c'));

    final recorded = await queue.flush();
    expect(recorded, 1);
    expect(service.calls, 2); // stopped at the offline item
    expect(await queue.pending(), hasLength(2)); // b and c kept
  });

  test('flush drops items the server definitively rejects', () async {
    final storage = InMemoryQueueStorage();
    final queue = AttendQueue(ScriptedAttend([serverGone]), storage);
    await queue.enqueue(gps('a'));

    final recorded = await queue.flush();
    expect(recorded, 0);
    expect(await queue.pending(), isEmpty); // not wedged forever
  });

  test('flush treats notFound as reached-the-server and drops it', () async {
    final storage = InMemoryQueueStorage();
    final queue = AttendQueue(ScriptedAttend([notFound]), storage);
    await queue.enqueue(gps('a'));

    expect(await queue.flush(), 0);
    expect(await queue.pending(), isEmpty);
  });

  test('flush on an empty queue is a no-op', () async {
    final queue = AttendQueue(ScriptedAttend([]), InMemoryQueueStorage());
    expect(await queue.flush(), 0);
  });
}
