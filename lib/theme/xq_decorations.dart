import 'package:flutter/material.dart';
import 'xq_colors.dart';

/// 拾晴日记 — 装饰常量：圆角、阴影、边框、卡片样式
class XqDecorations {
  XqDecorations._();

  // ── 圆角（微信风格：克制、精确）──
  static const radiusSmall = 4.0;
  static const radiusMedium = 8.0;
  static const radiusCard = 8.0;
  static const radiusLarge = 8.0;
  static const radiusHero = 8.0;
  static const radiusSheet = 8.0;

  // ── 阴影 ──
  static List<BoxShadow> shadowSubtle({bool dark = false}) => [
    BoxShadow(
      color: (dark ? Colors.black : XqColors.lightInk).withAlpha(dark ? 4 : 8),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> shadowMedium({bool dark = false}) => [
    BoxShadow(
      color: (dark ? Colors.black : XqColors.lightInk).withAlpha(dark ? 8 : 15),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> shadowStrong({bool dark = false}) => [
    BoxShadow(
      color: (dark ? Colors.black : XqColors.lightInk).withAlpha(
        dark ? 12 : 25,
      ),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];
  static List<BoxShadow> shadowGlow(Color accent) => [
    BoxShadow(color: accent.withAlpha(20), blurRadius: 16, spreadRadius: 2),
  ];

  // ── 边框 ──
  static Border borderThin(Color border) =>
      Border.all(color: border, width: 0.5);
  static Border borderMedium(Color border) =>
      Border.all(color: border, width: 1.0);
  static Border borderFocus(Color borderFocus) =>
      Border.all(color: borderFocus, width: 1.5);
  static Border borderAccent(Color accent) =>
      Border.all(color: accent.withAlpha(60), width: 1.0);

  // ═══════════════════════════════════════
  //  卡片模式
  // ═══════════════════════════════════════

  /// 高级卡片（天气轮播等）
  static BoxDecoration elevatedCard(
    Color cardElevated,
    Color accent, {
    bool dark = false,
  }) => BoxDecoration(
    color: cardElevated,
    borderRadius: BorderRadius.circular(radiusLarge),
    border: borderAccent(accent),
    boxShadow: [
      ...shadowMedium(dark: dark),
      ...shadowGlow(accent),
    ],
  );

  /// Hero 卡片（天气、语录、档案）
  static BoxDecoration heroCard(
    Color start,
    Color end,
    Color border, {
    bool dark = false,
    Color? glow,
  }) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [start, end],
    ),
    borderRadius: BorderRadius.circular(radiusHero),
    border: borderMedium(border),
    boxShadow: glow == null
        ? shadowMedium(dark: dark)
        : [...shadowMedium(dark: dark), ...shadowGlow(glow)],
  );

  /// 操作卡片（快捷入口、反馈）
  static BoxDecoration actionCard(
    Color card,
    Color border, {
    bool dark = false,
    Color? accent,
  }) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(radiusLarge),
    border: borderThin(accent == null ? border : accent.withAlpha(55)),
    boxShadow: shadowSubtle(dark: dark),
  );

  /// Sheet 表面（底部弹层）
  static BoxDecoration sheetSurface(
    Color card,
    Color border, {
    bool dark = false,
  }) => BoxDecoration(
    color: card,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(radiusSheet),
    ),
    border: Border(top: BorderSide(color: border.withAlpha(120), width: 0.5)),
    boxShadow: shadowStrong(dark: dark),
  );
}
