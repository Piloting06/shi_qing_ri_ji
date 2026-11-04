import 'package:flutter/material.dart';
import 'xq_colors.dart';

/// 一张纸的全部颜色与来历。主题 = 纸：浅色素笺 / 薛涛笺，深色磁青 / 乌金（ADR-0007）。
/// 纸纹、印、栏线、笺头画全部共用，只换纸色、墨色与印泥。对比度见 test/theme_regression_test.dart。
@immutable
class XqPalette {
  const XqPalette({
    required this.id,
    required this.name,
    required this.paper,
    required this.story,
    required this.legend,
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

  /// 来历（「我」页纸样下方）
  final String story;

  /// 换纸时浮现的两列竖排小字（按阅读顺序，右起）
  final List<String> legend;
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
    story: '宣纸出在安徽泾县，旧属宣州，因此得名。用青檀树皮和沙田稻草做成，有「纸寿千年」的说法。素笺是不染色的那一张，墨落上去最清楚。',
    legend: ['宣州造纸，青檀为皮', '一张白纸，纸寿千年'],
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

  /// 薛涛笺：桃红小笺。纸色明显偏红，印泥更深。
  static const xuetao = XqPalette(
    id: 'blush',
    name: '薛涛笺',
    paper: '桃红小笺',
    story: '唐代诗人薛涛住在成都浣花溪边，嫌常用的纸幅太大，自己用木芙蓉皮和芙蓉花汁做成桃红色的小笺，专门写诗。后人就叫它薛涛笺。',
    legend: ['浣花溪上，芙蓉染纸', '一笺桃红，只写短诗'],
    dark: false,
    background: Color(0xFFE6CCC3),
    card: Color(0xFFF4E2DB),
    cardElevated: Color(0xFFF7E9E3),
    sunken: Color(0xFFEBD3CA),
    frame: Color(0xFFCCA497),
    border: Color(0xFFE0C1B6),
    paperLine: Color(0xFFE2C5BA),
    controlBorder: Color(0xFF835C53),
    accent: Color(0xFF3A2224),
    accentLight: Color(0xFF5C4042),
    textPrimary: Color(0xFF2E1C1E),
    textSecondary: Color(0xFF573C3E),
    textTertiary: Color(0xFF664649),
    textOnAccent: Color(0xFFF4E2DB),
    error: Color(0xFF85281F),
    success: Color(0xFF41553A),
    warning: Color(0xFF654A22),
    ink: Color(0xFF3E2628),
    inkLight: Color(0x998C6A6A),
    gold: Color(0xFF773C28),
    seal: Color(0xFF962420),
    fiber: Color(0xFF7A2E2A),
    washi: [Color(0xFFDDB5AA), Color(0xFFC9BBAE), Color(0xFFE6CABF), Color(0xFFC7B1B3)],
  );

  // ── 深：两张纸 ──

  static const cixing = XqPalette(
    id: 'sujian_dark',
    name: '磁青',
    paper: '磁青纸，泥金',
    story: '用靛蓝一遍遍染出来的深青纸，颜色像青花瓷，所以叫磁青。明代宫里和寺院用泥金在上面抄经，纸是夜色，字是金的。',
    legend: ['靛蓝层层，染作夜色', '泥金一笔一笔写经'],
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

  /// 乌金：暖黑纸，银泥写字。
  static const wujin = XqPalette(
    id: 'dark',
    name: '乌金',
    paper: '乌金纸，银泥',
    story: '乌金纸本是打金箔时垫在中间的黑纸，又黑又亮。拓碑的人把墨色黑亮的拓本叫「乌金拓」。这一张取它的暖黑，字用银泥写，关了灯看最舒服。',
    legend: ['金箔之间的一张黑纸', '拓碑的墨色，黑而有光'],
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

  static const lights = [sujian, xuetao];
  static const darks = [cixing, wujin];
  static const all = [...lights, ...darks];

  static XqPalette? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    // 已合并的旧纸：暖笺（竹纸）、青笺（浅碧）并入素笺
    if (id == 'warm' || id == 'mint') return sujian;
    return null;
  }
}
