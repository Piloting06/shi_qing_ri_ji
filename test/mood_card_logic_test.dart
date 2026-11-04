import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/constants/mood.dart';
import 'package:xin_qing_ri_ji/utils/weather_utils.dart';
import 'package:xin_qing_ri_ji/widgets/mood_card/mood_card_data.dart';

void main() {
  group('weatherTextForCode', () {
    test('常见内部码映射', () {
      expect(weatherTextForCode(0), '晴');
      expect(weatherTextForCode(2), '多云');
      expect(weatherTextForCode(3), '阴');
      expect(weatherTextForCode(61), '小雨');
      expect(weatherTextForCode(95), '雷阵雨');
    });

    test('未知/超范围码返回空字符串', () {
      expect(weatherTextForCode(null), '');
      expect(weatherTextForCode(-1), '');
      expect(weatherTextForCode(999), '');
    });
  });

  group('computeMoodStats', () {
    final now = DateTime(2026, 9, 1, 10, 0); // 周二

    List<Map<String, dynamic>> mood(String date, int score) =>
        [{'date': date, 'emotion_type': score, 'notes': ''}];

    test('连续 N 天（含今天）', () {
      final moods = [
        ...mood('2026-09-01', 1),
        ...mood('2026-08-31', 2),
        ...mood('2026-08-30', 1),
      ];
      final s = computeMoodStats(moods, now);
      expect(s.streak, 3);
    });

    test('今天未记录则从昨天宽限计数', () {
      final moods = [
        ...mood('2026-08-31', 2),
        ...mood('2026-08-30', 1),
      ];
      final s = computeMoodStats(moods, now);
      expect(s.streak, 2);
    });

    test('断档归零', () {
      final moods = [
        ...mood('2026-09-01', 1),
        ...mood('2026-08-29', 1),
      ];
      final s = computeMoodStats(moods, now);
      expect(s.streak, 1);
    });

    test('一周窗口：今天在最前，记过的那天有颜料与心情字，没记的为空', () {
      final moods = [...mood('2026-09-01', 7)];
      final s = computeMoodStats(moods, now);
      expect(s.week.length, 7);
      expect(s.week.first.isToday, isTrue);
      expect(s.week.first.color, moodColors[7]);
      expect(s.week.first.mood, moodLabels[7]);
      expect(s.week[1].color, isNull);
      expect(s.week[1].mood, isNull);
      expect(s.week[6].label, '三'); // 8月26日是周三
    });

    test('空记录不崩溃', () {
      final s = computeMoodStats([], now);
      expect(s.streak, 0);
      expect(s.week.length, 7);
    });
  });

  group('inspirationLine', () {
    final now = DateTime(2026, 9, 1, 10, 0);
    final history = [
      {'date': '2026-08-20', 'emotion_type': 2, 'weather_code': '61'},
      {'date': '2026-08-15', 'emotion_type': 2, 'weather_code': '61'},
      {'date': '2026-08-10', 'emotion_type': 1, 'weather_code': '0'},
    ];

    test('雨天+平静出现历史次数签', () {
      final line = inspirationLine(
        weather: '小雨',
        moodScore: 2,
        moodLabel: '平静',
        streak: 0,
        history: history,
        now: now,
      );
      expect(line, contains('雨天'));
      expect(line, contains('第 2 次'));
    });

    test('连续记录达到阈值出火焰签', () {
      final line = inspirationLine(
        weather: '',
        moodScore: 1,
        moodLabel: '开心',
        streak: 5,
        history: [],
        now: now,
      );
      expect(line, contains('5 天'));
    });

    test('无数据时给出时段兜底签（不为空）', () {
      final line = inspirationLine(
        weather: '',
        moodScore: 1,
        moodLabel: '开心',
        streak: 0,
        history: [],
        now: DateTime(2026, 9, 1, 9, 0),
      );
      expect(line, isNotNull);
      expect(line, isNotEmpty);
    });

    test('同一天同心情输出稳定（确定性）', () {
      final a = inspirationLine(
        weather: '晴',
        moodScore: 1,
        moodLabel: '开心',
        streak: 0,
        history: [],
        now: now,
      );
      final b = inspirationLine(
        weather: '晴',
        moodScore: 1,
        moodLabel: '开心',
        streak: 0,
        history: [],
        now: now,
      );
      expect(a, b);
    });
  });
}
