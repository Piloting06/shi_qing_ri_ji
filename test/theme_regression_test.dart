import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/stores/theme_state.dart';
import 'package:xin_qing_ri_ji/theme/xq_palette.dart';
import 'package:xin_qing_ri_ji/theme/xq_theme.dart';

/// 回归：四张纸（素笺/薛涛笺 · 磁青/乌金）管线全覆盖 + 对比度 + 旧存值迁移。
void main() {
  double luminance(Color c) {
    double chan(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
  }

  double contrast(Color a, Color b) {
    final l1 = luminance(a), l2 = luminance(b);
    final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('四张纸 id 唯一，两浅两深，每张都有来历', () {
    expect(XqPalette.all.map((p) => p.id).toSet().length, 4);
    for (final p in XqPalette.all) {
      expect(p.story.length, greaterThan(30), reason: p.name);
      expect(p.legend.length, 2, reason: p.name);
      expect(p.legend.every((l) => l.length <= 10), isTrue, reason: '${p.name} 竖排每列不超过十字');
    }
    expect(XqPalette.lights.every((p) => !p.dark), isTrue);
    expect(XqPalette.darks.every((p) => p.dark), isTrue);
  });

  for (final p in XqPalette.all) {
    test('${p.name}：ThemeData 取色正确', () {
      final td = XqTheme.forPalette(p);
      expect(td.scaffoldBackgroundColor, p.background);
      expect(td.brightness, p.dark ? Brightness.dark : Brightness.light);
      expect(td.colorScheme.primary, p.accent);
      expect(XqTheme.forMode(p.id).scaffoldBackgroundColor, p.background);
    });

    test('${p.name}：文字、交互色、印在裱绫/笺/凹陷上都 ≥4.5，控件边框 ≥3', () {
      final inks = {
        '正文': p.textPrimary,
        '次要': p.textSecondary,
        '辅助': p.textTertiary,
        '交互色': p.accent,
        '日期数字': p.gold,
        '印泥': p.seal,
        '错误': p.error,
      };
      for (final g in [p.background, p.card, p.sunken]) {
        inks.forEach((label, c) {
          expect(contrast(c, g), greaterThanOrEqualTo(4.5),
              reason: '${p.name}：$label $c 在 $g 上只有 ${contrast(c, g).toStringAsFixed(2)}');
        });
      }
      expect(contrast(p.textOnAccent, p.accent), greaterThanOrEqualTo(4.5),
          reason: '${p.name}：按钮字');
      expect(contrast(p.controlBorder, p.background), greaterThanOrEqualTo(3.0),
          reason: '${p.name}：控件边框');
    });
  }

  test('旧主题存值迁移', () {
    // 没手动选过：跟随系统，记住纸
    expect(ThemeState.migrate(null, explicit: false), (XqAppearance.system, XqPalette.sujian));
    expect(ThemeState.migrate('warm', explicit: false).$1, XqAppearance.system);
    // 手动选过：按纸的深浅固定
    expect(ThemeState.migrate('sujian_dark', explicit: true), (XqAppearance.dark, XqPalette.cixing));
    expect(ThemeState.migrate('dark', explicit: true), (XqAppearance.dark, XqPalette.wujin));
    // 已合并的暖笺 / 青笺 → 素笺
    expect(ThemeState.migrate('mint', explicit: true), (XqAppearance.light, XqPalette.sujian));
    expect(ThemeState.migrate('warm', explicit: true), (XqAppearance.light, XqPalette.sujian));
    expect(ThemeState.migrate('blush', explicit: true), (XqAppearance.light, XqPalette.xuetao));
    expect(ThemeState.migrate('nonsense', explicit: true), (XqAppearance.system, XqPalette.sujian));
  });

  test('同深浅的两张纸一眼分得开（裱绫色差够大）', () {
    double dist(Color a, Color b) =>
        math.sqrt(math.pow(a.r - b.r, 2) + math.pow(a.g - b.g, 2) + math.pow(a.b - b.b, 2)) * 255;
    expect(dist(XqPalette.sujian.background, XqPalette.xuetao.background), greaterThan(18));
    expect(dist(XqPalette.cixing.background, XqPalette.wujin.background), greaterThan(12));
  });
}
