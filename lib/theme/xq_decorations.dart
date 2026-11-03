import 'package:flutter/material.dart';
import 'xq_colors.dart';

/// 拾晴日记 — 装饰常量：圆角、阴影、边框、卡片样式
class XqDecorations {
  XqDecorations._();

  // ── 圆角：纸是方的（P9 笺谱）。笺 3、控件 4、弹层 6；圆角只为抗锯齿，不为「圆润」──
  static const radiusSmall = 2.0;
  static const radiusControl = 4.0;
  static const radiusMedium = 4.0;
  static const radiusCard = 3.0;
  static const radiusLarge = 3.0;
  static const radiusHero = 3.0;
  static const radiusSheet = 6.0;

  static const _warmInk = Color(0xFF3B2F22);

  /// L1 笺的「纸厚」：一道 1px 的接触影，不是浮起来的投影
  static List<BoxShadow> lift({bool dark = false}) => [
    BoxShadow(
      color: (dark ? Colors.black : _warmInk).withAlpha(dark ? 60 : 16),
      blurRadius: 1.5,
      offset: const Offset(0, 1),
    ),
  ];

  /// L2 叠上来的一张纸（首页覆盖天色的纸、弹层）：全 App 唯一的投影
  static List<BoxShadow> sheetLift({bool dark = false}) => [
    BoxShadow(
      color: (dark ? Colors.black : _warmInk).withAlpha(dark ? 120 : 40),
      blurRadius: 24,
      offset: const Offset(0, -6),
    ),
  ];

  /// L1 笺：更亮的纸 + 一圈细墨线（装裱的画心边）+ 纸厚
  static BoxDecoration surface(
    Color card, {
    bool dark = false,
    Color? edge,
    double radius = radiusCard,
    DecorationImage? grain,
  }) => BoxDecoration(
    color: card,
    image: grain,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: edge ?? (dark ? const Color(0xFF3A4556) : const Color(0xFFC6BDAA)), width: 0.6),
    boxShadow: lift(dark: dark),
  );

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

  // 三个历史卡片助手保留签名，统一产出 L1 笺

  /// 高级卡片（天气轮播等）
  static BoxDecoration elevatedCard(
    Color cardElevated,
    Color accent, {
    bool dark = false,
  }) => surface(cardElevated, dark: dark);

  /// Hero 卡片（天气、语录、档案）
  static BoxDecoration heroCard(
    Color start,
    Color end,
    Color border, {
    bool dark = false,
    Color? glow,
  }) => surface(start, dark: dark, edge: border, radius: radiusHero);

  /// 操作卡片（快捷入口、反馈）
  static BoxDecoration actionCard(
    Color card,
    Color border, {
    bool dark = false,
    Color? accent,
  }) => surface(card, dark: dark, edge: border);

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
