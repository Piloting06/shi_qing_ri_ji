import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/widgets/weather_sky.dart';

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('天气码 → 天况（码优先，文案兜底）', () {
    expect(skyConditionFor(0), SkyCondition.clear);
    expect(skyConditionFor(2), SkyCondition.cloudy);
    expect(skyConditionFor(3), SkyCondition.overcast);
    expect(skyConditionFor(45), SkyCondition.fog);
    expect(skyConditionFor(61), SkyCondition.rain);
    expect(skyConditionFor(95), SkyCondition.rain);
    expect(skyConditionFor(73), SkyCondition.snow);
    expect(skyConditionFor(null, '小雪'), SkyCondition.snow);
    expect(skyConditionFor(null, '阴'), SkyCondition.overcast);
    expect(skyConditionFor(null, null), SkyCondition.clear);
  });

  test('时辰：日出日落前后一小时为晨暮，无数据按 6/18 点', () {
    DateTime at(int h, int m) => DateTime(2026, 11, 3, h, m);
    expect(skyTimeFor(at(6, 40), sunrise: '06:31', sunset: '17:24'), SkyTime.dawn);
    expect(skyTimeFor(at(12, 0), sunrise: '06:31', sunset: '17:24'), SkyTime.day);
    expect(skyTimeFor(at(17, 30), sunrise: '06:31', sunset: '17:24'), SkyTime.dusk);
    expect(skyTimeFor(at(20, 0), sunrise: '06:31', sunset: '17:24'), SkyTime.night);
    expect(skyTimeFor(at(3, 0)), SkyTime.night);
    expect(skyTimeFor(at(12, 0), sunrise: '坏数据'), SkyTime.day);
  });

  test('24 套天色：天上文字对天顶与天中对比度 ≥4.5', () {
    for (final c in SkyCondition.values) {
      for (final t in SkyTime.values) {
        final p = SkyPalette.of(c, t);
        for (final bg in [p.top, p.mid]) {
          expect(_contrast(p.onSky, bg), greaterThanOrEqualTo(4.5),
              reason: '$c/$t 主文字对比不足');
          expect(_contrast(p.onSkySoft, bg), greaterThanOrEqualTo(4.5),
              reason: '$c/$t 次文字对比不足');
        }
      }
    }
  });

  test('中文数字与温度', () {
    expect(chineseTemperature(16), '十六度');
    expect(chineseTemperature(10), '十度');
    expect(chineseTemperature(20), '二十度');
    expect(chineseTemperature(35), '三十五度');
    expect(chineseTemperature(0), '零度');
    expect(chineseTemperature(-3), '零下三度');
    expect(chineseNumber(11), '十一');
  });

  test('天气短句：所有组合非空、无破折号与感叹号', () {
    for (final c in SkyCondition.values) {
      for (final t in SkyTime.values) {
        for (var d = 0; d < 3; d++) {
          final s = skyLine(c, t, dayOfYear: d);
          expect(s, isNotEmpty);
          expect(s.contains('—') || s.contains('！'), isFalse, reason: s);
        }
      }
    }
  });

  test('计数用「两」', () {
    expect(chineseCount(2), '两');
    expect(chineseCount(3), '三');
    expect(chineseCount(12), '十二');
  });
}
