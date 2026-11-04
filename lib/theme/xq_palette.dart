import 'package:flutter/material.dart';
import 'xq_colors.dart';

/// 一张纸的全部颜色。P10 起主题 = 纸：浅色四张（素笺/暖笺/青笺/藕笺），深色两张（磁青/黛笺）。
/// 纸纹、印、栏线、笺头画全部共用，只换纸色、墨色与印泥。对比度见 test/theme_regression_test.dart。
@immutable
class XqPalette {
  const XqPalette({
    required this.id,
    required this.name,
    required this.paper,
    required this.story,
    required this.dark,
    required this.background,
    required this.card,
    required this.cardElevated,
    required this.sunken,
    required this.frame,
    required this.border,
    required this.paperLine,
    required this.controlBorder,
    required this.accent,
    required this.accentLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.error,
    required this.success,
    required this.warning,
    required this.ink,
    required this.inkLight,
    required this.gold,
    required this.seal,
    required this.fiber,
    required this.washi,
  });

  /// 存储用 id（沿用旧主题 id，老用户的选择能直接对上）
  final String id;
  final String name;

  /// 一句话：这是什么纸
  final String paper;

  /// 来历（选择器里再点一次时展示）
  final String story;
  final bool dark;

  final Color background; // L0 裱绫
  final Color card; // L1 笺
  final Color cardElevated; // 弹层
  final Color sunken; // 笺内凹陷
  final Color frame; // 笺框细线
  final Color border; // 乌丝栏
  final Color paperLine;
  final Color controlBorder; // 控件边框 ≥3:1
  final Color accent; // 唯一交互色
  final Color accentLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;
  final Color error;
  final Color success;
  final Color warning;
  final Color ink; // 手绘装饰墨
  final Color inkLight;
  final Color gold; // 日期、数字
  final Color seal; // 印泥
  final Color fiber; // 纸纹染色
  final List<Color> washi;

  Color get accentMuted => accent.withAlpha(dark ? 0x33 : 0x2E);
  Color get borderFocus => accent;

  // ── 浅：四张纸 ──

  static const sujian = XqPalette(
    id: 'sujian',
    name: '素笺',
    paper: '生宣，本色',
    story: '没染过色的宣纸，偏一点米黄。墨落上去最清楚，适合大多数时候。',
    dark: false,
    background: XqColors.sujianBackground,
    card: XqColors.sujianCard,
    cardElevated: XqColors.sujianCardElevated,
    sunken: XqColors.sujianSunken,
    frame: XqColors.sujianFrame,
    border: XqColors.sujianBorder,
    paperLine: XqColors.sujianPaperLine,
    controlBorder: XqColors.sujianControlBorder,
    accent: XqColors.sujianAccent,
    accentLight: XqColors.sujianAccentLight,
    textPrimary: XqColors.sujianTextPrimary,
    textSecondary: XqColors.sujianTextSecondary,
    textTertiary: XqColors.sujianTextTertiary,
    textOnAccent: XqColors.sujianTextOnAccent,
    error: XqColors.sujianError,
    success: XqColors.sujianSuccess,
    warning: XqColors.sujianWarning,
    ink: XqColors.sujianInk,
    inkLight: XqColors.sujianInkLight,
    gold: XqColors.sujianGold,
    seal: XqColors.sujianSeal,
    fiber: XqColors.sujianPaperFiber,
    washi: [XqColors.sujianWashi1, XqColors.sujianWashi2, XqColors.sujianWashi3, XqColors.sujianWashi4],
  );

  /// 暖笺：竹纸。纸色黄一些，墨偏褐，印泥用老朱。
  static const warm = XqPalette(
    id: 'warm',
    name: '暖笺',
    paper: '竹纸，微黄',
    story: '竹子做的纸，比宣纸黄、纤维更粗，旧书多用它印。夜里灯下看着不刺眼。',
    dark: false,
    background: Color(0xFFE2D5BB),
    card: Color(0xFFF2E9D5),
    cardElevated: Color(0xFFF6EFDF),
    sunken: Color(0xFFE9DEC6),
    frame: Color(0xFFC2B08C),
    border: Color(0xFFDACBAE),
    paperLine: Color(0xFFDCCDB0),
    controlBorder: Color(0xFF7D6F55),
    accent: Color(0xFF33281C),
    accentLight: Color(0xFF54473A),
    textPrimary: Color(0xFF2A2118),
    textSecondary: Color(0xFF54483A),
    textTertiary: Color(0xFF615444),
    textOnAccent: Color(0xFFF2E9D5),
    error: Color(0xFF8C3523),
    success: Color(0xFF475F3A),
    warning: Color(0xFF6A5526),
    ink: Color(0xFF3A2E22),
    inkLight: Color(0x998A7A62),
    gold: Color(0xFF774B24),
    seal: Color(0xFFA6361C),
    fiber: Color(0xFF5A4220),
    washi: [Color(0xFFD9C59E), Color(0xFFBFC2A2), Color(0xFFE3D2AE), Color(0xFFC4BBA6)],
  );

  /// 青笺：浅碧染笺，墨偏青黑。
  static const mint = XqPalette(
    id: 'mint',
    name: '青笺',
    paper: '染笺，浅碧',
    story: '用靛青极淡地染过一遍的笺，像雨后的天色。墨也跟着偏一点青。',
    dark: false,
    background: Color(0xFFD5DDD6),
    card: Color(0xFFEDF1EB),
    cardElevated: Color(0xFFF2F5F0),
    sunken: Color(0xFFE2E8E1),
    frame: Color(0xFFADBDB2),
    border: Color(0xFFCCD6CD),
    paperLine: Color(0xFFCFD9D0),
    controlBorder: Color(0xFF68796F),
    accent: Color(0xFF21302A),
    accentLight: Color(0xFF3D4D46),
    textPrimary: Color(0xFF1C2622),
    textSecondary: Color(0xFF44524B),
    textTertiary: Color(0xFF4F5D56),
    textOnAccent: Color(0xFFEDF1EB),
    error: Color(0xFF8A3428),
    success: Color(0xFF3B5E45),
    warning: Color(0xFF615729),
    ink: Color(0xFF26332D),
    inkLight: Color(0x99708078),
    gold: Color(0xFF6B4D2E),
    seal: Color(0xFFA2352A),
    fiber: Color(0xFF2E4A3E),
    washi: [Color(0xFFB9CCC0), Color(0xFFC9D3BE), Color(0xFFD6DCCF), Color(0xFFB6C3C6)],
  );

  /// 藕笺：薛涛笺一路的浅红染笺，淡到只剩一点藕色。
  static const blush = XqPalette(
    id: 'blush',
    name: '藕笺',
    paper: '染笺，藕色',
    story: '照薛涛笺的路子染的浅红笺，淡到只剩一点藕色。写信、写想念的人合适。',
    dark: false,
    background: Color(0xFFE5D6D1),
    card: Color(0xFFF5EDE9),
    cardElevated: Color(0xFFF8F2EF),
    sunken: Color(0xFFECE1DC),
    frame: Color(0xFFC9B2AA),
    border: Color(0xFFDCCBC5),
    paperLine: Color(0xFFDECDC7),
    controlBorder: Color(0xFF7D6A64),
    accent: Color(0xFF30252A),
    accentLight: Color(0xFF52454A),
    textPrimary: Color(0xFF2A1F22),
    textSecondary: Color(0xFF55464A),
    textTertiary: Color(0xFF625257),
    textOnAccent: Color(0xFFF5EDE9),
    error: Color(0xFF8E3230),
    success: Color(0xFF4A5E46),
    warning: Color(0xFF6A5229),
    ink: Color(0xFF3A2C30),
    inkLight: Color(0x99877479),
    gold: Color(0xFF784735),
    seal: Color(0xFFA0302A),
    fiber: Color(0xFF5A3238),
    washi: [Color(0xFFDDC2BE), Color(0xFFC9C5BA), Color(0xFFE4D3CB), Color(0xFFC6BAC4)],
  );

  // ── 深：两张纸 ──

  static const cixing = XqPalette(
    id: 'sujian_dark',
    name: '磁青',
    paper: '磁青纸，泥金',
    story: '靛蓝反复染出来的深青纸，古人用泥金在上面写经。夜里看着最安静。',
    dark: true,
    background: XqColors.sujianDarkBackground,
    card: XqColors.sujianDarkCard,
    cardElevated: XqColors.sujianDarkCardElevated,
    sunken: XqColors.sujianDarkSunken,
    frame: XqColors.sujianDarkFrame,
    border: XqColors.sujianDarkBorder,
    paperLine: XqColors.sujianDarkPaperLine,
    controlBorder: XqColors.sujianDarkControlBorder,
    accent: XqColors.sujianDarkAccent,
    accentLight: XqColors.sujianDarkAccentLight,
    textPrimary: XqColors.sujianDarkTextPrimary,
    textSecondary: XqColors.sujianDarkTextSecondary,
    textTertiary: XqColors.sujianDarkTextTertiary,
    textOnAccent: XqColors.sujianDarkTextOnAccent,
    error: XqColors.sujianDarkError,
    success: XqColors.sujianDarkSuccess,
    warning: XqColors.sujianDarkWarning,
    ink: XqColors.sujianDarkInk,
    inkLight: XqColors.sujianDarkInkLight,
    gold: XqColors.sujianDarkGold,
    seal: XqColors.sujianDarkSeal,
    fiber: XqColors.sujianDarkPaperFiber,
    washi: [XqColors.sujianDarkWashi1, XqColors.sujianDarkWashi2, XqColors.sujianDarkWashi3, XqColors.sujianDarkWashi4],
  );

  /// 黛笺：乌金纸一路的暖黑纸，银泥写字。
  static const dai = XqPalette(
    id: 'dark',
    name: '黛笺',
    paper: '乌金纸，银泥',
    story: '近乎黑的暖色纸，字用银泥写。比磁青更沉，屏幕更暗，适合关了灯以后。',
    dark: true,
    background: Color(0xFF171614),
    card: Color(0xFF201E1B),
    cardElevated: Color(0xFF272522),
    sunken: Color(0xFF2A2824),
    frame: Color(0xFF433F38),
    border: Color(0xFF322F2A),
    paperLine: Color(0xFF302D28),
    controlBorder: Color(0xFF7A746A),
    accent: Color(0xFFCFCABE),
    accentLight: Color(0xFFE0DCD2),
    textPrimary: Color(0xFFE8E4DA),
    textSecondary: Color(0xFFBBB5A8),
    textTertiary: Color(0xFF9C968A),
    textOnAccent: Color(0xFF171614),
    error: Color(0xFFE09A8C),
    success: Color(0xFFA6BF9C),
    warning: Color(0xFFD6BD86),
    ink: Color(0xFFD9D4C9),
    inkLight: Color(0xCC857E72),
    gold: Color(0xFFC4A66E),
    seal: Color(0xFFD8735C),
    fiber: Color(0xFFD8CFBD),
    washi: [Color(0xFF423D35), Color(0xFF34403A), Color(0xFF4A4034), Color(0xFF3A3D44)],
  );

  static const lights = [sujian, warm, mint, blush];
  static const darks = [cixing, dai];
  static const all = [...lights, ...darks];

  static XqPalette? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
