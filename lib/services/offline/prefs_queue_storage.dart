import 'package:shared_preferences/shared_preferences.dart';

import 'attend_queue.dart';

/// [QueueStorage] backed by SharedPreferences (Keychain/Keystore-adjacent on
/// device, localStorage on web). Survives app restarts.
class PrefsQueueStorage implements QueueStorage {
  PrefsQueueStorage({this.key = 'attend_queue_v1'});

  final String key;

  @override
  Future<List<String>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? <String>[];
  }

  @override
  Future<void> writeAll(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setStringList(key, items);
    }
  }
}
