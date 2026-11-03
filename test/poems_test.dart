import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/data/poems.dart';
import 'package:xin_qing_ri_ji/utils/solar_term_utils.dart';
import 'package:xin_qing_ri_ji/widgets/weather_sky.dart';

void main() {
  test('每种天况 × 四季都有不放宽季节就能配上的句子', () {
    const seasons = ['spring', 'summer', 'autumn', 'winter'];
    for (final c in SkyCondition.values) {
      for (final s in seasons) {
        final ok = poems.any((p) =>
            p.conditions.contains(c) && (p.seasons.isEmpty || p.seasons.contains(s)) && p.date == null);
        expect(ok, isTrue, reason: '$c · $s 没有可配的句子');
      }
    }
  });

  test('每句两列、每列 4–7 字、不带标点', () {
    final punct = RegExp(r'[，。、？！；：「」]');
    for (final p in poems) {
      expect(p.lines.length, 2, reason: p.title);
      for (final l in p.lines) {
        expect(l.length, inInclusiveRange(4, 7), reason: l);
        expect(punct.hasMatch(l), isFalse, reason: l);
      }
    }
  });

  test('选句：日期命中优先，节气其次，同一天稳定', () {
    final nov4 = DateTime(2026, 11, 4, 21);
    expect(poemFor(SkyCondition.rain, SkyTime.night, nov4).title, '十一月四日风雨大作');
    // 白天的雨不配夜句，退到霜降节气句
    expect(poemFor(SkyCondition.rain, SkyTime.day, nov4).terms, contains('霜降'));
    final a = poemFor(SkyCondition.clear, SkyTime.day, DateTime(2026, 5, 2, 9));
    final b = poemFor(SkyCondition.clear, SkyTime.day, DateTime(2026, 5, 2, 15));
    expect(a, same(b));
  });

  test('任何一天任何天况都能取到句子', () {
    for (var d = DateTime(2026); d.year == 2026; d = d.add(const Duration(days: 11))) {
      for (final c in SkyCondition.values) {
        for (final t in SkyTime.values) {
          expect(poemFor(c, t, d).lines, hasLength(2));
        }
      }
    }
  });

  test('节气第几天', () {
    expect(daysIntoSolarTerm(DateTime(2026, 10, 23)), 1);
    expect(daysIntoSolarTerm(DateTime(2026, 11, 4)), 13);
    expect(daysIntoSolarTerm(DateTime(2026, 1, 3)), 13); // 上一年冬至 12-22 起
  });
}
