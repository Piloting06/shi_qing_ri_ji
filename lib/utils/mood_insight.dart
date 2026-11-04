import '../widgets/xq/xq_icons.dart';
import '../constants/mood.dart';

class MoodInsight {
  final String text;
  final XqIcons icon;

  const MoodInsight(this.text, this.icon);
}

/// Computes a one-line insight from mood history.
/// Returns null if not enough data or no rule matches.
MoodInsight? computeMoodInsight(
  List<Map<String, dynamic>> allMoods,
  DateTime today,
) {
  if (allMoods.length < 3) return null;

  // Group by date
  final byDate = <String, List<Map<String, dynamic>>>{};
  for (final m in allMoods) {
    final d = m['date'] as String? ?? '';
    if (d.isEmpty) continue;
    byDate.putIfAbsent(d, () => []).add(m);
  }

  // Current week (Monday-Sunday)
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final thisWeekDates = List.generate(
    7,
    (i) => _fmt(weekStart.add(Duration(days: i))),
  );
  final thisWeekDays =
      thisWeekDates.where((d) => byDate.containsKey(d)).length;

  // Last week
  final lastWeekStart = weekStart.subtract(const Duration(days: 7));
  final lastWeekDates = List.generate(
    7,
    (i) => _fmt(lastWeekStart.add(Duration(days: i))),
  );
  final lastWeekDays =
      lastWeekDates.where((d) => byDate.containsKey(d)).length;

  // Priority 1: Full week
  if (thisWeekDays == 7) {
    return const MoodInsight(
      '这周七天都记了',
      XqIcons.spark,
    );
  }

  // Priority 2: 5-6 days this week
  if (thisWeekDays >= 5) {
    return MoodInsight(
      '这周记了 $thisWeekDays 天',
      XqIcons.flame,
    );
  }

  // Priority 3: 3 consecutive days of positive mood
  final recentDates = byDate.keys.take(10).toList();
  if (recentDates.length >= 3) {
    final recent3 = recentDates.take(3).toList();
    final scores = recent3.map((d) {
      final moods = byDate[d]!;
      return _readScore(moods.last['emotion_type']);
    }).toList();
    final allPositive = scores.every((s) => s == 1 || s == 7); // happy or expect
    if (allPositive) {
      final label = moodLabels[scores.first] ?? '开心';
      return MoodInsight(
        '最近三天都是「$label」',
        XqIcons.sunny,
      );
    }
  }

  // Priority 4: Tough week (sad + anxious + angry > 4)
  final toughWeekCount = thisWeekDates
      .expand((d) => byDate[d] ?? [])
      .where((m) {
        final s = _readScore(m['emotion_type']);
        return s == 3 || s == 4 || s == 5; // sad, angry, anxious
      })
      .length;
  if (toughWeekCount >= 4) {
    return const MoodInsight(
      '这几天心情不太好',
      XqIcons.heart,
    );
  }

  // Priority 5: Monthly milestone
  final monthStart = DateTime(today.year, today.month, 1);
  final monthCount = byDate.keys.where((d) {
    final dt = DateTime.tryParse(d);
    return dt != null &&
        dt.isAfter(monthStart.subtract(const Duration(days: 1))) &&
        dt.isBefore(today.add(const Duration(days: 1)));
  }).fold(0, (sum, d) => sum + (byDate[d]?.length ?? 0));
  if (monthCount >= 20) {
    return MoodInsight(
      '这个月记了 $monthCount 条',
      XqIcons.book,
    );
  }

  // Priority 6: Improvement vs last week
  if (thisWeekDays > lastWeekDays + 1 && lastWeekDays > 0) {
    return MoodInsight(
      '上周记了 $lastWeekDays 天，这周 $thisWeekDays 天',
      XqIcons.trend,
    );
  }

  // Priority 7: Most frequent mood
  final freq = <int, int>{};
  for (final m in allMoods.take(30)) {
    final s = _readScore(m['emotion_type']);
    if (s > 0) freq[s] = (freq[s] ?? 0) + 1;
  }
  if (freq.isNotEmpty) {
    final top =
        freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final label = moodLabels[top] ?? '';
    return MoodInsight(
      '这阵子记得最多的是「$label」',
      _moodIcon(top),
    );
  }

  return null;
}

int _readScore(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

XqIcons _moodIcon(int score) {
  return switch (score) {
    1 => XqIcons.faceGood,
    2 => XqIcons.leaf,
    3 => XqIcons.faceMeh,
    4 => XqIcons.faceBad,
    5 => XqIcons.spark,
    6 => XqIcons.moon,
    7 => XqIcons.spark,
    8 => XqIcons.heart,
    _ => XqIcons.faceGood,
  };
}
