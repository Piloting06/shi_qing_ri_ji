import 'package:flutter/material.dart';

/// 拾晴日记 — 字体系统（素笺规范，ADR-0004）
/// 三层各司其职：
/// - 展示（Display = 朱雀仿宋子集，OFL；缺字退思源宋 SerifSC）：Display/Headline 仪式层——天上的大字、页题、名字、题跋
///   P9 笺谱：仿宋是刻本/活字的气质，只有一个字重，展示层统一 w400，靠字号分层
/// - 黑（系统无衬线）：界面正文、标签、按钮——不设 fontFamily，走系统默认
/// - 楷（LXGW WenKai）：只属于内容层——日记正文、故事、胶囊信、卡片（用 [content]）
/// 数字使用 tabular-nums 由调用处按需叠加。
class XqTypography {
  XqTypography._();

  /// 内容层字体（用户写下的字）。界面控件不要用。
  static const content = 'LXGW WenKai';

  /// 霞鹜文楷缺「」『』“”等标点，缺字退到宋体子集；〇与竖排标点再退到展示体子集（同属书写气质，不混入黑体）
  static const contentFallback = <String>['SerifSC', 'Display'];
  static const serif = 'Display';

  /// 思源宋子集：印章字、需要字重的地方（Display 只有一个字重）
  static const song = 'SerifSC';
  static const _serifFallback = <String>[
    'SerifSC',
    'Noto Serif SC',
    'Source Han Serif SC',
    'Songti SC',
  ];

  // ── Display（宋）──
  static const displayLarge = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    height: 1.3,
  );
  static const displayMedium = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.8,
    height: 1.3,
  );
  static const displaySmall = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.35,
  );

  // ── Headline（宋，字重收敛：禅意排版忌粗黑大标题）──
  static const headlineLarge = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.4,
  );
  static const headlineMedium = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.45,
  );
  static const headlineSmall = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── Body（黑，界面正文）──
  static const bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static const bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ── Label（黑）──
  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
  static const labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  // ── Button（黑）──
  static const button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  // ── 内容层（楷）──
  static const handwrittenBody = TextStyle(
    fontFamily: content,
    fontFamilyFallback: contentFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.85,
    letterSpacing: 0.3,
  );
  static const splashTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 4.0,
    height: 1.3,
  );
}
