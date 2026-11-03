import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/theme/xq_colors.dart';
import 'package:xin_qing_ri_ji/theme/xq_theme.dart';

/// 回归：6 套主题（素笺/夜墨/暖笺/黛笺/青笺/藕笺）管线全覆盖。
/// 防止新增主题漏接 getter 分支导致静默回退到默认色。
void main() {
  const modes = ['sujian', 'sujian_dark', 'warm', 'dark', 'mint', 'blush'];

  double luminance(Color c) {
    double chan(double v) {
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
  }

  double contrast(Color a, Color b) {
    final l1 = luminance(a), l2 = luminance(b);
    final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('全部 6 套主题都能产出 ThemeData 且背景色正确', () {
    final expectedBg = {
      'sujian': XqColors.sujianBackground, // 宣纸
      'sujian_dark': XqColors.sujianDarkBackground, // 磁青
      'warm': const Color(0xFFFAF4EC),
      'dark': const Color(0xFF0E1222),
      'mint': const Color(0xFFDDEBE3),
      'blush': const Color(0xFFF2DED8),
    };
    for (final mode in modes) {
      final td = XqTheme.forMode(mode);
      expect(td.scaffoldBackgroundColor, expectedBg[mode],
          reason: '主题 $mode 的背景色与色板不符');
    }
  });

  // 文字色在 paper / surface / sunken 三种底上都要达标
  void checkContrast(String name, List<Color> grounds, Map<String, (Color, double)> inks) {
    for (final g in grounds) {
      inks.forEach((label, spec) {
        final (c, min) = spec;
        expect(contrast(c, g), greaterThanOrEqualTo(min),
            reason: '$name：$label 在 $g 上对比度不足 $min');
      });
    }
  }

  test('素笺宣纸：文字与控件对比度达标', () {
    checkContrast('素笺', [
      XqColors.sujianBackground,
      XqColors.sujianCard,
      XqColors.sujianSunken,
    ], {
      '正文': (XqColors.sujianTextPrimary, 4.5),
      '次要': (XqColors.sujianTextSecondary, 4.5),
      '辅助': (XqColors.sujianTextTertiary, 4.5),
      '交互色': (XqColors.sujianAccent, 4.5),
      '赭': (XqColors.sujianGold, 4.5),
      '朱砂': (XqColors.sujianSeal, 4.5),
    });
    expect(contrast(XqColors.sujianControlBorder, XqColors.sujianBackground),
        greaterThanOrEqualTo(3.0));
  });

  test('磁青：文字与控件对比度达标', () {
    checkContrast('磁青', [
      XqColors.sujianDarkBackground,
      XqColors.sujianDarkCard,
      XqColors.sujianDarkSunken,
    ], {
      '正文': (XqColors.sujianDarkTextPrimary, 4.5),
      '次要': (XqColors.sujianDarkTextSecondary, 4.5),
      '辅助': (XqColors.sujianDarkTextTertiary, 4.5),
      '交互色': (XqColors.sujianDarkAccent, 4.5),
      '赭': (XqColors.sujianDarkGold, 4.5),
      '朱砂': (XqColors.sujianDarkSeal, 4.5),
    });
    expect(contrast(XqColors.sujianDarkControlBorder, XqColors.sujianDarkBackground),
        greaterThanOrEqualTo(3.0));
  });
}
