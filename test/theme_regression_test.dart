import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      'sujian': const Color(0xFFEFEFE9), // 瓦白
      'sujian_dark': const Color(0xFF141719), // 黛夜
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

  test('素笺烟雨：正文与辅助文字对比度达标', () {
    const paper = Color(0xFFEFEFE9);
    expect(contrast(const Color(0xFF262B2E), paper), greaterThanOrEqualTo(4.5),
        reason: '正文墨色对比度不足');
    expect(contrast(const Color(0xFF55524A), paper), greaterThanOrEqualTo(4.5),
        reason: '次要文字对比度不足');
    expect(contrast(const Color(0xFF5D656B), paper), greaterThanOrEqualTo(3.0),
        reason: '辅助文字对比度不足 3:1');
  });

  test('素笺夜雨：正文对比度达标', () {
    const paper = Color(0xFF141719);
    expect(contrast(const Color(0xFFE2E6E1), paper), greaterThanOrEqualTo(4.5),
        reason: '夜雨正文对比度不足');
    expect(contrast(const Color(0xFF8AACAE), paper), greaterThanOrEqualTo(3.0),
        reason: '夜雨交互色对比度不足 3:1');
  });
}
