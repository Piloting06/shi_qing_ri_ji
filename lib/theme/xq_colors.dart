import 'package:flutter/material.dart';

/// 拾晴日记 — 设计系统颜色 Token
/// 素笺、磁青两张纸的原始色值；六张纸的完整色板见 xq_palette.dart
class XqColors {
  XqColors._();

  /// 旧暖色墨（仅 XqDecorations 的浅色阴影仍用）。其余老主题色板已由 XqPalette 取代（ADR-0006）
  static const lightInk = Color(0xFF3B2B20);

  // ═══════════════════════════════════════
  //  素笺 · 宣纸（笺谱：裱绫 + 笺 + 墨 + 朱砂 + 赭；P9 起交互色由深檀改为墨）
  //  层级靠「装裱」：L0 裱绫偏深、L1 笺更亮并有一圈细墨线，不靠投影。对比度见 test/theme_regression_test.dart
  // ═══════════════════════════════════════

  static const sujianBackground = Color(0xFFE6E0D3); // L0 裱绫
  static const sujianCard = Color(0xFFF7F4EC); // L1 笺
  static const sujianCardElevated = Color(0xFFFAF8F2); // 弹层
  static const sujianAccent = Color(0xFF2C2A25); // 墨（唯一交互色）
  static const sujianAccentLight = Color(0xFF4A463E);
  static const sujianAccentMuted = Color(0x2E2C2A25);
  static const sujianTextPrimary = Color(0xFF22211C); // 墨
  static const sujianTextSecondary = Color(0xFF514D45);
  static const sujianTextTertiary = Color(0xFF5F5A51);
  static const sujianTextOnAccent = Color(0xFFF7F4EC);
  static const sujianBorder = Color(0xFFDCD4C4); // 笺内分隔细线（乌丝栏）
  static const sujianFrame = Color(0xFFC6BDAA); // 笺的外框细墨线
  static const sujianBorderFocus = Color(0xFF2C2A25);
  static const sujianError = Color(0xFF8F382E);
  static const sujianSuccess = Color(0xFF456548);
  static const sujianWarning = Color(0xFF6C5C2E);
  static const sujianInk = Color(0xFF33302A); // 手绘装饰用墨
  static const sujianInkLight = Color(0x99857E70);
  static const sujianGold = Color(0xFF7A5232); // 赭（日期、数字）
  static const sujianControlBorder = Color(0xFF7E776A); // 控件边框 ≥3:1（裱绫底上）
  static const sujianPaperLine = Color(0xFFDDD5C5);
  static const sujianSeal = Color(0xFFAE3624); // 朱砂：只给印与钤印
  static const sujianSunken = Color(0xFFEDE8DE); // 笺内凹陷：标签、输入
  static const sujianPaperFiber = Color(0xFF4A3B26); // 纸纹染色（暖墨）

  // 和纸胶带色（宣纸版：赭/青/米/灰蓝，低饱和）
  static const sujianWashi1 = Color(0xFFD8CBB3);
  static const sujianWashi2 = Color(0xFFB9C7BF);
  static const sujianWashi3 = Color(0xFFE2D6BF);
  static const sujianWashi4 = Color(0xFFB7C0C4);

  // ═══════════════════════════════════════
  //  磁青 · 泥金（深色：靛染深青纸 + 泥金 + 月白；古人以泥金在磁青纸上写经）
  // ═══════════════════════════════════════

  static const sujianDarkBackground = Color(0xFF141B26); // L0 磁青
  static const sujianDarkCard = Color(0xFF1C2431); // L1
  static const sujianDarkCardElevated = Color(0xFF232C3A);
  static const sujianDarkAccent = Color(0xFFCDAE72); // 泥金
  static const sujianDarkAccentLight = Color(0xFFDDC48F);
  static const sujianDarkAccentMuted = Color(0x33CDAE72);
  static const sujianDarkTextPrimary = Color(0xFFE6E7E2); // 月白
  static const sujianDarkTextSecondary = Color(0xFFB7BCC2);
  static const sujianDarkTextTertiary = Color(0xFF9199A3);
  static const sujianDarkTextOnAccent = Color(0xFF141B26);
  static const sujianDarkBorder = Color(0xFF2C3646);
  static const sujianDarkFrame = Color(0xFF3A4556);
  static const sujianDarkBorderFocus = Color(0xFFCDAE72);
  static const sujianDarkError = Color(0xFFE59A8E);
  static const sujianDarkSuccess = Color(0xFF9CC0A4);
  static const sujianDarkWarning = Color(0xFFD8BF84);
  static const sujianDarkInk = Color(0xFFD5D9DC);
  static const sujianDarkInkLight = Color(0xCC7D8796);
  static const sujianDarkGold = Color(0xFFC9A96C); // 泥金（日期、数字）
  static const sujianDarkControlBorder = Color(0xFF6F7A8A);
  static const sujianDarkPaperLine = Color(0xFF2A3342);
  static const sujianDarkSeal = Color(0xFFDC7A64);
  static const sujianDarkSunken = Color(0xFF252E3C); // 深色下凹陷取比卡片亮一档的面
  static const sujianDarkPaperFiber = Color(0xFFC9D2DE); // 纸纹染色（月白）

  static const sujianDarkWashi1 = Color(0xFF3A4252);
  static const sujianDarkWashi2 = Color(0xFF2F4441);
  static const sujianDarkWashi3 = Color(0xFF443E33);
  static const sujianDarkWashi4 = Color(0xFF34404F);
}
