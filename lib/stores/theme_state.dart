import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';
import '../theme/xq_colors.dart';

class ThemeState extends ChangeNotifier {
  String _themeMode = 'sujian';
  bool _transitioning = false;

  bool get transitioning => _transitioning;
  String get themeMode => _themeMode;
  bool get isDark => _themeMode == 'dark' || _themeMode == 'sujian_dark';

  /// 凹陷区（素笺：比纸深一层的标签/代码底），其余主题回退到卡片色
  Color get sunkenColor => switch (_themeMode) {
    'sujian' => XqColors.sujianSunken,
    'sujian_dark' => XqColors.sujianDarkSunken,
    _ => cardColor,
  };

  /// 朱砂小印：素笺专属品牌点睛色（每屏至多一处），其余主题回退到各自的点缀色
  Color get sealColor => switch (_themeMode) {
    'sujian' => XqColors.sujianSeal,
    'sujian_dark' => XqColors.sujianDarkSeal,
    _ => gold,
  };

  static const Map<String, String> themeNames = {
    'sujian': '素笺',
    'sujian_dark': '素笺 · 夜墨',
    'warm': '暖笺',
    'dark': '黛笺',
    'mint': '青笺',
    'blush': '藕笺',
  };

  static const Map<String, List<Color>> themeColors = {
    'sujian': [XqColors.sujianAccent, XqColors.sujianCard, XqColors.sujianBackground],
    'sujian_dark': [XqColors.sujianDarkAccent, XqColors.sujianDarkCard, XqColors.sujianDarkBackground],
    'warm': [XqColors.lightAccent, XqColors.lightCard, XqColors.lightBackground],
    'dark': [XqColors.darkAccent, XqColors.darkCard, XqColors.darkBackground],
    'mint': [XqColors.mintAccent, XqColors.mintCard, XqColors.mintBackground],
    'blush': [XqColors.blushAccent, XqColors.blushCard, XqColors.blushBackground],
  };

  ThemeState() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getString(StorageKeys.themeMode) ?? 'warm';
    // Migrate old 'light' → 'warm'
    if (stored == 'light') stored = 'warm';
    // 素笺默认迁移：从未显式挑过主题（仍是出厂默认 warm）的用户迁到素笺；
    // 显式选过（mint/blush/dark 等）的尊重其选择。
    final explicit = prefs.getBool(StorageKeys.themeExplicit) ?? false;
    var next = themeNames.containsKey(stored) ? stored : 'warm';
    if (!explicit && stored == 'warm') next = 'sujian';
    _themeMode = next;
    if (next != stored || !explicit) {
      await prefs.setString(StorageKeys.themeMode, next);
    }
    notifyListeners();
  }

  Future<void> setTheme(String mode) async {
    final next = themeNames.containsKey(mode) ? mode : 'sujian';
    if (_themeMode == next) return;
    _transitioning = true;
    _themeMode = next;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(StorageKeys.themeMode, next);
      prefs.setBool(StorageKeys.themeExplicit, true);
    });
    await Future.delayed(const Duration(milliseconds: 280));
    _transitioning = false;
    notifyListeners();
  }

  // ── Color getters indexed by theme ──

  Color get backgroundColor => switch (_themeMode) {
    'sujian' => XqColors.sujianBackground,
    'sujian_dark' => XqColors.sujianDarkBackground,
    'dark' => XqColors.darkBackground,
    'mint' => XqColors.mintBackground,
    'blush' => XqColors.blushBackground,
    _ => XqColors.sujianBackground,
  };

  Color get cardColor => switch (_themeMode) {
    'sujian' => XqColors.sujianCard,
    'sujian_dark' => XqColors.sujianDarkCard,
    'dark' => XqColors.darkCard,
    'mint' => XqColors.mintCard,
    'blush' => XqColors.blushCard,
    _ => XqColors.sujianCard,
  };

  Color get cardElevated => switch (_themeMode) {
    'sujian' => XqColors.sujianCardElevated,
    'sujian_dark' => XqColors.sujianDarkCardElevated,
    'dark' => XqColors.darkCardElevated,
    'mint' => XqColors.mintCardElevated,
    'blush' => XqColors.blushCardElevated,
    _ => XqColors.sujianCardElevated,
  };

  Color get accentColor => switch (_themeMode) {
    'sujian' => XqColors.sujianAccent,
    'sujian_dark' => XqColors.sujianDarkAccent,
    'dark' => XqColors.darkAccent,
    'mint' => XqColors.mintAccent,
    'blush' => XqColors.blushAccent,
    _ => XqColors.sujianAccent,
  };

  Color get accentLight => switch (_themeMode) {
    'sujian' => XqColors.sujianAccentLight,
    'sujian_dark' => XqColors.sujianDarkAccentLight,
    'dark' => XqColors.darkAccentLight,
    'mint' => XqColors.mintAccentLight,
    'blush' => XqColors.blushAccentLight,
    _ => XqColors.sujianAccentLight,
  };

  Color get accentMuted => switch (_themeMode) {
    'sujian' => XqColors.sujianAccentMuted,
    'sujian_dark' => XqColors.sujianDarkAccentMuted,
    'dark' => XqColors.darkAccentMuted,
    'mint' => XqColors.mintAccentMuted,
    'blush' => XqColors.blushAccentMuted,
    _ => XqColors.sujianAccentMuted,
  };

  Color get textPrimary => switch (_themeMode) {
    'sujian' => XqColors.sujianTextPrimary,
    'sujian_dark' => XqColors.sujianDarkTextPrimary,
    'dark' => XqColors.darkTextPrimary,
    'mint' => XqColors.mintTextPrimary,
    'blush' => XqColors.blushTextPrimary,
    _ => XqColors.sujianTextPrimary,
  };

  Color get textSecondary => switch (_themeMode) {
    'sujian' => XqColors.sujianTextSecondary,
    'sujian_dark' => XqColors.sujianDarkTextSecondary,
    'dark' => XqColors.darkTextSecondary,
    'mint' => XqColors.mintTextSecondary,
    'blush' => XqColors.blushTextSecondary,
    _ => XqColors.sujianTextSecondary,
  };

  Color get textTertiary => switch (_themeMode) {
    'sujian' => XqColors.sujianTextTertiary,
    'sujian_dark' => XqColors.sujianDarkTextTertiary,
    'dark' => XqColors.darkTextTertiary,
    'mint' => XqColors.mintTextTertiary,
    'blush' => XqColors.blushTextTertiary,
    _ => XqColors.sujianTextTertiary,
  };

  Color get textOnAccent => switch (_themeMode) {
    'sujian' => XqColors.sujianTextOnAccent,
    'sujian_dark' => XqColors.sujianDarkTextOnAccent,
    'dark' => XqColors.darkTextOnAccent,
    _ => XqColors.sujianTextOnAccent,
  };

  Color get borderColor => switch (_themeMode) {
    'sujian' => XqColors.sujianBorder,
    'sujian_dark' => XqColors.sujianDarkBorder,
    'dark' => XqColors.darkBorder,
    'mint' => XqColors.mintBorder,
    'blush' => XqColors.blushBorder,
    _ => XqColors.sujianBorder,
  };

  Color get borderFocus => switch (_themeMode) {
    'sujian' => XqColors.sujianBorderFocus,
    'sujian_dark' => XqColors.sujianDarkBorderFocus,
    'dark' => XqColors.darkBorderFocus,
    'mint' => XqColors.mintBorderFocus,
    'blush' => XqColors.blushBorderFocus,
    _ => XqColors.sujianBorderFocus,
  };

  Color get errorColor => switch (_themeMode) {
    'sujian' => XqColors.sujianError,
    'sujian_dark' => XqColors.sujianDarkError,
    'dark' => XqColors.darkError,
    _ => XqColors.sujianError,
  };

  Color get successColor => switch (_themeMode) {
    'sujian' => XqColors.sujianSuccess,
    'sujian_dark' => XqColors.sujianDarkSuccess,
    'dark' => XqColors.darkSuccess,
    _ => XqColors.sujianSuccess,
  };

  Color get warningColor => switch (_themeMode) {
    'sujian' => XqColors.sujianWarning,
    'sujian_dark' => XqColors.sujianDarkWarning,
    'dark' => XqColors.darkWarning,
    _ => XqColors.sujianWarning,
  };

  Color get ink => switch (_themeMode) {
    'sujian' => XqColors.sujianInk,
    'sujian_dark' => XqColors.sujianDarkInk,
    'dark' => XqColors.darkInk,
    'mint' => XqColors.mintInk,
    'blush' => XqColors.blushInk,
    _ => XqColors.sujianInk,
  };

  Color get inkLight => switch (_themeMode) {
    'sujian' => XqColors.sujianInkLight,
    'sujian_dark' => XqColors.sujianDarkInkLight,
    'dark' => XqColors.darkInkLight,
    'mint' => XqColors.mintInkLight,
    'blush' => XqColors.blushInkLight,
    _ => XqColors.sujianInkLight,
  };

  Color get gold => switch (_themeMode) {
    'sujian' => XqColors.sujianGold,
    'sujian_dark' => XqColors.sujianDarkGold,
    'dark' => XqColors.darkGold,
    'mint' => XqColors.mintGold,
    'blush' => XqColors.blushGold,
    _ => XqColors.sujianGold,
  };

  Color get paperLine => switch (_themeMode) {
    'sujian' => XqColors.sujianPaperLine,
    'sujian_dark' => XqColors.sujianDarkPaperLine,
    'dark' => XqColors.darkPaperLine,
    'mint' => XqColors.mintPaperLine,
    'blush' => XqColors.blushPaperLine,
    _ => XqColors.sujianPaperLine,
  };

  Color get surfaceAlpha => switch (_themeMode) {
    'sujian' => XqColors.sujianAccent.withAlpha(20),
    'sujian_dark' => XqColors.sujianDarkAccent.withAlpha(24),
    'dark' => Colors.white.withAlpha(12),
    'mint' => XqColors.mintAccent.withAlpha(20),
    'blush' => XqColors.blushAccent.withAlpha(20),
    _ => XqColors.sujianAccent.withAlpha(20),
  };

  List<Color> get washiColors => switch (_themeMode) {
    'sujian' => [XqColors.sujianWashi1, XqColors.sujianWashi2, XqColors.sujianWashi3, XqColors.sujianWashi4],
    'sujian_dark' => [XqColors.sujianDarkWashi1, XqColors.sujianDarkWashi2, XqColors.sujianDarkWashi3, XqColors.sujianDarkWashi4],
    'dark' => [XqColors.darkWashi1, XqColors.darkWashi2, XqColors.darkWashi3, XqColors.darkWashi4],
    'mint' => [XqColors.mintWashi1, XqColors.mintWashi2, XqColors.mintWashi3, XqColors.mintWashi4],
    'blush' => [XqColors.blushWashi1, XqColors.blushWashi2, XqColors.blushWashi3, XqColors.blushWashi4],
    _ => [XqColors.sujianWashi1, XqColors.sujianWashi2, XqColors.sujianWashi3, XqColors.sujianWashi4],
  };
}
