import 'package:flutter/material.dart';
import '../../constants/mood.dart';

/// 心情卡片模板共享数据包：模板是无状态的，所有可编辑内容都从这里来
class MoodCardData {
  final String dateText;
  final String rawDate; // YYYY-MM-DD 原始日期（节气等按真实日期计算）
  final int moodScore;
  final String moodEmoji;
  final String moodLabel;
  final String moodEn;
  final String bodyText;
  final List<String> tags;
  final String username;
  final String watermark; // cn | en | sq | sqrj | xiaoqing
  final String? weatherText;
  final String? cityName;
  final String? temperature;
  final bool square; // false=温润圆角 true=方寸直角
  final int streakDays; // 连续记录天数（含今天或昨天）
  final List<MoodDay> week; // 最近7天（今天在前）
  final double height; // 卡片高度：216=竖版，约等于卡宽=方图
  final double bodyScale; // 正文字号缩放（1.0 标准 / 0.9 小字）

  const MoodCardData({
    required this.dateText,
    this.rawDate = '',
    required this.moodScore,
    required this.moodEmoji,
    required this.moodLabel,
    required this.moodEn,
    required this.bodyText,
    required this.tags,
    required this.username,
    required this.watermark,
    this.weatherText,
    this.cityName,
    this.temperature,
    required this.square,
    this.streakDays = 0,
    this.week = const [],
    this.height = 216,
    this.bodyScale = 1.0,
  });
}

/// 单日心情聚合（用于火焰卡/周历卡）
class MoodDay {
  final String label; // 星期缩写
  final String? emoji;
  final int? color; // moodColors 值
  final bool isToday;

  const MoodDay({
    required this.label,
    this.emoji,
    this.color,
    required this.isToday,
  });
}

/// 由全部心情记录计算：连续天数 + 最近7天聚合
/// moods 元素至少含 date(YYYY-MM-DD) 和 emotion_type(int)
({
  int streak,
  List<MoodDay> week,
}) computeMoodStats(List<Map<String, dynamic>> moods, DateTime now) {
  // 按日期聚合（一天多条取最后一条的心情）
  final byDate = <String, Map<String, dynamic>>{};
  for (final m in moods) {
    final d = m['date']?.toString();
    if (d == null || d.isEmpty) continue;
    byDate[d] = m;
  }

  // 连续天数：从今天往前数；今天没记则从昨天开始（宽限）
  var streak = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  if (!byDate.containsKey(_fmt(cursor))) cursor = cursor.subtract(const Duration(days: 1));
  while (byDate.containsKey(_fmt(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // 最近7天：今天在最前
  const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
  final week = <MoodDay>[];
  for (int i = 0; i < 7; i++) {
    final day = now.subtract(Duration(days: i));
    final rec = byDate[_fmt(day)];
    if (rec == null) {
      week.add(MoodDay(label: weekLabels[day.weekday - 1], isToday: i == 0));
    } else {
      final score = (rec['emotion_type'] as num?)?.toInt();
      week.add(MoodDay(
        label: weekLabels[day.weekday - 1],
        emoji: score != null ? (moodEmojis[score] ?? '') : '',
        color: score != null ? moodColors[score] : null,
        isToday: i == 0,
      ));
    }
  }
  return (streak: streak, week: week);
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


/// 水印文案（共享给各模板）
String watermarkTextFor(String watermark) => switch (watermark) {
  'cn' => '拾晴日记',
  'sq' => 'sq.',
  'sqrj' => 's q r j',
  'xiaoqing' => '小晴',
  _ => 'SHI QING',
};

/// 模板描述与注册表：新增模板 = 写一个 builder + 在这里注册一行
class MoodCardTemplateSpec {
  final String id;
  final String name; // 中文名（色点提示用）
  final String label; // 卡面右上角 branding
  final List<Color> dotColors; // 选择器色点渐变
  final Widget Function(MoodCardData data) buildCard;

  const MoodCardTemplateSpec({
    required this.id,
    required this.name,
    required this.label,
    required this.dotColors,
    required this.buildCard,
  });
}

/// 心晴签：基于当天天气×心情×历史的个性化短语（差异化内容层）
/// 返回 null 表示没有合适的灵感
String? inspirationLine({
  required String? weather,
  required int moodScore,
  required String moodLabel,
  required int streak,
  required List<Map<String, dynamic>> history,
  DateTime? now,
}) {
  final d = now ?? DateTime.now();
  final w = weather ?? '';
  String weatherCat(String? codeText) {
    final c = int.tryParse(codeText ?? '') ?? -1;
    if (c == 0) return '晴天';
    if (c == 2) return '多云';
    if (c == 3 || c == 45) return '阴天';
    if (c >= 51 && c < 70) return '雨天';
    if (c >= 71 && c < 80) return '雪天';
    if (c >= 80) return '阵雨';
    return '';
  }

  final candidates = <String>[];

  // 1) 同天气×同心情的历史次数（数据越攒越多的部分）
  final todayCat = weatherCatForText(w);
  if (todayCat.isNotEmpty && moodScore > 0) {
    var n = 0;
    for (final m in history) {
      if (weatherCat(m['weather_code']?.toString()) == todayCat &&
          (m['emotion_type'] as num?)?.toInt() == moodScore) {
        n++;
      }
    }
    if (n >= 2) {
      candidates.add('这是你在$todayCat里写下「$moodLabel」的第 $n 次');
    }
  }

  // 2) 连续记录
  if (streak >= 3) {
    candidates.add('连续记了 $streak 天');
  }

  // 3) 天气情景
  final weatherLines = <String>[
    if (w.contains('晴')) '晴天写的',
    if (w.contains('雨')) '雨天写的',
    if (w.contains('雪')) '下雪那天写的',
    if (w.contains('云')) '多云那天写的',
    if (w.contains('阴')) '阴天写的',
  ];
  candidates.addAll(weatherLines);

  // 4) 时段
  candidates.add(
    d.hour < 6
        ? '夜里写的'
        : d.hour < 11
            ? '早上写的'
            : d.hour < 18
                ? '下午写的'
                : '傍晚写的',
  );

  if (candidates.isEmpty) return null;
  // 按日期+心情做确定性轮换（同一天同心情给同一句，改了心情换一句）
  final idx = (d.day + moodScore) % candidates.length;
  return candidates[idx];
}

/// 把天气文本映射到类别（与 weather_code 类别对齐）
String weatherCatForText(String w) {
  if (w.contains('雪')) return '雪天';
  if (w.contains('雨') || w.contains('雷')) return '雨天';
  if (w.contains('阴') || w.contains('雾') || w.contains('霾')) return '阴天';
  if (w.contains('云')) return '多云';
  if (w.contains('晴')) return '晴天';
  return '';
}
