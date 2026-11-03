/// 节气与（公历）节日计算。
/// 节气每年公历日期浮动 ±1 天，这里用常用平均日期，装饰用途足够。
library;

const _solarTerms = <String, (int, int)>{
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

const _festivals = <String, (int, int)>{
  '元旦': (1, 1),
  '情人节': (2, 14),
  '妇女节': (3, 8),
  '劳动节': (5, 1),
  '儿童节': (6, 1),
  '国庆节': (10, 1),
  '平安夜': (12, 24),
  '圣诞节': (12, 25),
  '跨年夜': (12, 31),
};

/// 当天命中的节日名（优先于节气）；无则返回 null
String? festivalOf(DateTime d) {
  for (final e in _festivals.entries) {
    if (e.value.$1 == d.month && e.value.$2 == d.day) return e.key;
  }
  return null;
}

/// 当天命中的节气名；无则返回 null（节气当天±0，非窗口期）
String? solarTermOf(DateTime d) {
  for (final e in _solarTerms.entries) {
    if (e.value.$1 == d.month && e.value.$2 == d.day) return e.key;
  }
  return null;
}

/// 当前节气区间名（一年按 24 段划分，任何一天都命中一个节气）
String currentSolarTerm(DateTime d) {
  // 把节气按一年中的顺序排开，找今天所处区间
  final entries = _solarTerms.entries
      .map((e) => (name: e.key, date: DateTime(d.year, e.value.$1, e.value.$2)))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  String current = entries.last.name; // 1月落在"冬至"之后
  for (final e in entries) {
    if (d.isAfter(e.date)) current = e.name;
  }
  return current;
}

/// 节气 → 季节（spring/summer/autumn/winter）
String seasonOfTerm(String term) {
  const map = {
    '立春': 'spring', '雨水': 'spring', '惊蛰': 'spring', '春分': 'spring',
    '清明': 'spring', '谷雨': 'spring',
    '立夏': 'summer', '小满': 'summer', '芒种': 'summer', '夏至': 'summer',
    '小暑': 'summer', '大暑': 'summer',
    '立秋': 'autumn', '处暑': 'autumn', '白露': 'autumn', '秋分': 'autumn',
    '寒露': 'autumn', '霜降': 'autumn',
    '立冬': 'winter', '小雪': 'winter', '大雪': 'winter', '冬至': 'winter',
    '小寒': 'winter', '大寒': 'winter',
  };
  return map[term] ?? 'spring';
}

/// 进入当前节气的第几天（节气当天为第 1 天）。1 月初落在上一年冬至之后。
int daysIntoSolarTerm(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  // currentSolarTerm 用 isAfter 判区间，零点正落在节气当天会被算进上一个；取正午避开边界
  final term = currentSolarTerm(day.add(const Duration(hours: 12)));
  final (m, dd) = _solarTerms[term]!;
  var start = DateTime(day.year, m, dd);
  if (start.isAfter(day)) start = DateTime(day.year - 1, m, dd);
  return day.difference(start).inDays + 1;
}
