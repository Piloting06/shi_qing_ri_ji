import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 素笺故事：本地长文写作存储（documents/stories/）
/// 隐私原则：长文只存本机，不上传服务器。
class StoryEntry {
  final String id;
  final String title;
  final String content;
  final String createdAt; // ISO
  final String updatedAt; // ISO
  final int moodScore; // 关联心情（0=未关联）
  final String weatherText; // 关联天气（可空）

  const StoryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.moodScore = 0,
    this.weatherText = '',
  });

  StoryEntry copyWith({
    String? title,
    String? content,
    String? updatedAt,
    int? moodScore,
    String? weatherText,
  }) =>
      StoryEntry(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        moodScore: moodScore ?? this.moodScore,
        weatherText: weatherText ?? this.weatherText,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'moodScore': moodScore,
        'weatherText': weatherText,
      };

  static StoryEntry fromJson(Map<String, dynamic> j) => StoryEntry(
        id: j['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: j['title']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        createdAt: j['createdAt']?.toString() ?? '',
        updatedAt: j['updatedAt']?.toString() ?? '',
        moodScore: (j['moodScore'] as num?)?.toInt() ?? 0,
        weatherText: j['weatherText']?.toString() ?? '',
      );
}

class StoryStore {
  static const _indexFile = 'stories.json';

  static Future<Directory> dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'stories'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<List<StoryEntry>> load() async {
    try {
      final d = await dir();
      final f = File(p.join(d.path, _indexFile));
      if (!f.existsSync()) return [];
      final list = (json.decode(await f.readAsString()) as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StoryEntry.fromJson)
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  /// 新建或更新（按 id），返回保存后的条目
  static Future<StoryEntry> save(StoryEntry entry) async {
    final d = await dir();
    final entries = await load();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.insert(0, entry);
    }
    final f = File(p.join(d.path, _indexFile));
    await f.writeAsString(json.encode(entries.map((e) => e.toJson()).toList()));
    return entry;
  }

  static Future<void> delete(String id) async {
    final d = await dir();
    final entries = await load();
    entries.removeWhere((e) => e.id == id);
    final f = File(p.join(d.path, _indexFile));
    await f.writeAsString(json.encode(entries.map((e) => e.toJson()).toList()));
  }
}
