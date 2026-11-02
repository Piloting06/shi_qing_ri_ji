import 'package:flutter/material.dart';

/// 拾晴日记 — 字体系统（素笺规范）
/// 界面两层：宋体（Display/Headline 仪式层级，走系统宋回退）+ 楷体（正文/标签，
/// LXGW WenKai 已打包，即"手写字保留在内容层"的实现载体）。
/// 数字使用 tabular-nums 由调用处按需叠加。
class XqTypography {
  XqTypography._();

  static const _ff = 'LXGW WenKai';
  static const _serifFallback = <String>[
    'Noto Serif SC',
    'Source Han Serif SC',
    'Songti SC',
  ];

  // ── Display（宋）──
  static const displayLarge = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.0,
    height: 1.3,
  );
  static const displayMedium = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 1.3,
  );
  static const displaySmall = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    height: 1.35,
  );

  // ── Headline（宋，字重收敛：禅意排版忌粗黑大标题）──
  static const headlineLarge = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );
  static const headlineMedium = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.45,
  );
  static const headlineSmall = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  // ── Body（楷，内容与正文）──
  static const bodyLarge = TextStyle(
    fontFamily: _ff,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.7,
  );
  static const bodyMedium = TextStyle(
    fontFamily: _ff,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static const bodySmall = TextStyle(
    fontFamily: _ff,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── Label（楷）──
  static const labelLarge = TextStyle(
    fontFamily: _ff,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
  static const labelMedium = TextStyle(
    fontFamily: _ff,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
  static const labelSmall = TextStyle(
    fontFamily: _ff,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  // ── Button（楷）──
  static const button = TextStyle(
    fontFamily: _ff,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  // ── 专用样式 ──
  static const handwrittenBody = TextStyle(
    fontFamily: _ff,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.9,
    letterSpacing: 0.3,
  );
  static const splashTitle = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 4.0,
    height: 1.3,
  );
}
