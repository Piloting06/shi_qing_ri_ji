import '../constants/mood.dart';

/// 节气章：把一个节气时段的心情记录织成一段叙事。
/// 系统起笔，用户完笔——生成结果会预填进素笺写作页，由用户编辑后成为自己的故事。
class StoryChapter {
  final String title; // 章节标题，如「霜降 · 十五日」
  final String body; // 章节正文（可编辑的起笔稿）
  final int entryCount; // 该时段记录条数

  const StoryChapter({
    required this.title,
    required this.body,
    required this.entryCount,
  });
}

StoryChapter? generateSeasonChapter(
  List<Map<String, dynamic>> moods,
  DateTime now,
) {
  // ── 计算当前节气段的起点 ──
  final entries = _termDates(now.year)
    ..sort((a, b) => a.date.compareTo(b.date));
  DateTime? termStart;
  var termName = '';
  for (final t in entries) {
    if (t.date.isBefore(now) || t.date.isAtSameMomentAs(now)) {
      termStart = t.date;
      termName = t.name;
    }
  }
  if (termStart == null) {
    // 一月初落在上一年的冬至之后：取上年冬至
    termStart = DateTime(now.year - 1, 12, 22);
    termName = '冬至';
  }

  final days = now.difference(termStart).inDays + 1;

  // ── 该时段的记录 ──
  final inTerm = moods.where((m) {
    final d = m['date']?.toString() ?? '';
    if (d.length != 10) return false;
    final dd = DateTime.tryParse(d);
    return dd != null && !dd.isBefore(termStart!) && !dd.isAfter(now);
  }).toList();

  if (inTerm.isEmpty) return null;

  // ── 统计 ──
  final counts = <int, int>{};
  var sunny = 0;
  var rainy = 0;
  for (final m in inTerm) {
    final score = (m['emotion_type'] as num?)?.toInt();
    if (score != null) counts[score] = (counts[score] ?? 0) + 1;
    final code = int.tryParse(m['weather_code']?.toString() ?? '') ?? -1;
    if (code == 0) sunny++;
    if ((code >= 51 && code < 80)) rainy++;
  }
  var topScore = 0;
  var topCount = 0;
  counts.forEach((score, n) {
    if (n > topCount) {
      topCount = n;
      topScore = score;
    }
  });
  final topLabel = moodLabels[topScore] ?? '';

  // ── 叙事（克制、不感叹、不指导）──
  final weatherPart = [
    if (sunny > 0) '晴 $sunny 天',
    if (rainy > 0) '雨 $rainy 天',
  ].join('、');
  final weatherSentence =
      weatherPart.isEmpty ? '' : '这${_cnDays(days)}里，$weatherPart。';
  final moodSentence = topLabel.isEmpty
      ? ''
      : '写得最多的，是「$topLabel」，共 $topCount 次。';
  final closing = switch (topScore) {
    1 => '好日子，值得多记一笔。',
    2 => '静水深流，都在纸上了。',
    3 => '难过的日子，也值得被记下。',
    4 => '写下来，火气就有了去处。',
    5 => '一件件写清，就不算压着。',
    6 => '累了就少写一点，没关系。',
    7 => '盼着的事，先记在这里。',
    8 => '思念有处可放。',
    _ => '',
  };

  final body = [weatherSentence, moodSentence, closing].where((s) => s.isNotEmpty).join('\n');

  return StoryChapter(
    title: '$termName · ${_cnDays(days)}',
    body: body,
    entryCount: inTerm.length,
  );
}

String _cnDays(int d) => '$d 天';

/// 一年的 24 个节气日（按常用平均日期）
List<({String name, DateTime date})> _termDates(int year) {
  const table = <String, (int, int)>{
    '小寒': (1, 6), '大寒': (1, 20),
    '立春': (2, 4), '雨水': (2, 19),
    '惊蛰': (3, 6), '春分': (3, 21),
    '清明': (4, 5), '谷雨': (4, 20),
    '立夏': (5, 6), '小满': (5, 21), '芒种': (6, 6),
    '夏至': (6, 21), '小暑': (7, 7), '大暑': (7, 23),
    '立秋': (8, 8), '处暑': (8, 23),
    '白露': (9, 8), '秋分': (9, 23),
    '寒露': (10, 8), '霜降': (10, 23),
    '立冬': (11, 7), '小雪': (11, 22),
    '大雪': (12, 7), '冬至': (12, 22),
  };
  return table.entries
      .map((e) => (name: e.key, date: DateTime(year, e.value.$1, e.value.$2)))
      .toList();
}
