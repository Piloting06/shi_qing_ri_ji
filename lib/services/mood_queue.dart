import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';
import '../api/api_base.dart';
import '../api/mood_api.dart';

class MoodQueue {
  static Future<void> enqueue(Map<String, dynamic> moodData) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _load(prefs);
    list.add({
      ...moodData,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(StorageKeys.moodPendingQueue, json.encode(list));
  }

  /// Flushes the queue. Returns number of records successfully sent.
  static Future<int> flush() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _load(prefs);
    if (list.isEmpty) return 0;

    final sent = <int>[];
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      try {
        await MoodApi.saveMood(
          item['date'] as String,
          item['emotion_type'] as int,
          (item['notes'] as String?) ?? '',
          ((item['emotion_tags'] as String?) ?? '')
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
          [],
        );
        sent.add(i);
      } on ApiException catch (e) {
        // 服务器明确拒收（4xx，例如字数超限）：这条重试也不会成功，丢掉，别卡住后面的
        if (e.statusCode >= 400 && e.statusCode < 500 && e.statusCode != 401 && e.statusCode != 429) {
          sent.add(i);
          continue;
        }
        break;
      } catch (_) {
        break; // 网络还没恢复，下次再试
      }
    }

    if (sent.isNotEmpty) {
      final remaining = list
          .asMap()
          .entries
          .where((e) => !sent.contains(e.key))
          .map((e) => e.value)
          .toList();
      await prefs.setString(
        StorageKeys.moodPendingQueue,
        json.encode(remaining),
      );
    }
    return sent.length;
  }

  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs).length;
  }

  static List<Map<String, dynamic>> _load(SharedPreferences prefs) {
    final raw = prefs.getString(StorageKeys.moodPendingQueue);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
