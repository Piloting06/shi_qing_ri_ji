import 'package:flutter/material.dart';
import 'xq_colors.dart';

/// 拾晴日记 — 装饰常量：圆角、阴影、边框、卡片样式
class XqDecorations {
  XqDecorations._();

  // ── 圆角：三层表面各有其形（L0 页面 / L1 卡片 16 / L2 面板 24），控件 12、标签 8 ──
  static const radiusSmall = 8.0;
  static const radiusMedium = 12.0;
  static const radiusCard = 16.0;
  static const radiusLarge = 16.0;
  static const radiusHero = 20.0;
  static const radiusSheet = 24.0;

  // ── 抬升：暖墨色双层柔影（大而淡的环境影 + 小而实的接触影）──
  static const _warmInk = Color(0xFF3B2F22);

  /// L1 卡片
  static List<BoxShadow> lift({bool dark = false}) => [
    BoxShadow(
      color: (dark ? Colors.black : _warmInk).withAlpha(dark ? 70 : 18),
      blurRadius: 28,
      spreadRadius: -6,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: (dark ? Colors.black : _warmInk).withAlpha(dark ? 50 : 10),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  /// L2 面板（自下而上覆盖天色的那张纸）
  static List<BoxShadow> sheetLift({bool dark = false}) => [
    BoxShadow(
      color: (dark ? Colors.black : _warmInk).withAlpha(dark ? 110 : 34),
      blurRadius: 36,
      offset: const Offset(0, -8),
    ),
  ];

  /// L1 卡片装饰（深色下补一道极细的亮边，阴影在暗底上看不见）
  static BoxDecoration surface(Color card, {bool dark = false, Color? edge, double radius = radiusCard}) =>
      BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: dark ? Border.all(color: edge ?? const Color(0xFF2E2B27), width: 0.6) : null,
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

  // 三个历史卡片助手保留签名，统一产出 L1 卡片（圆角 16 + 暖色柔影）

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
