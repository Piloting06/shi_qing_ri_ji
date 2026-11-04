import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';
import '../theme/xq_palette.dart';

/// 深浅怎么定：跟随系统 / 总是浅 / 总是深
enum XqAppearance { system, light, dark }

/// 主题 = 纸（素笺 / 薛涛笺 · 磁青 / 乌金）。浅色、深色各记一张纸；跟随系统时按手机深浅在两张之间切换。
/// 页面通过各颜色 getter 取色，换纸时由 [XqThemeReveal] 把旧画面截下来、让新纸从点按处晕开。
class ThemeState extends ChangeNotifier with WidgetsBindingObserver {
  XqAppearance _appearance = XqAppearance.system;
  XqPalette _lightPaper = XqPalette.sujian;
  XqPalette _darkPaper = XqPalette.cixing;
  bool _systemDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  bool _loaded = false;

  /// 本地偏好已读出（读出那一下的变化不做过渡动画）
  bool get loaded => _loaded;

  /// 下一次换纸从哪里晕开（全局坐标）；用一次就清掉
  Offset? revealOrigin;

  /// 这次换纸要不要讲这张纸的来历（从纸样点进来的才讲）；用一次就清掉
  XqPalette? storyPaper;

  ThemeState() {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final next = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    if (next == _systemDark) return;
    _systemDark = next;
    if (_appearance == XqAppearance.system) notifyListeners();
  }

  XqAppearance get appearance => _appearance;
  XqPalette get lightPaper => _lightPaper;
  XqPalette get darkPaper => _darkPaper;

  bool get isDark => switch (_appearance) {
        XqAppearance.system => _systemDark,
        XqAppearance.light => false,
        XqAppearance.dark => true,
      };

  /// 当前在用的纸
  XqPalette get palette => isDark ? _darkPaper : _lightPaper;

  /// 当前纸的 id（兼容旧调用）
  String get themeMode => palette.id;

  /// 旧存值 → (深浅, 纸)。v2.21 只有素笺/磁青；更早的暖笺/黛笺/青笺/藕笺 id 原样认回。
  static (XqAppearance, XqPalette) migrate(String? stored, {required bool explicit}) {
    final p = XqPalette.byId(stored);
    if (!explicit || p == null) return (XqAppearance.system, p ?? XqPalette.sujian);
    return (p.dark ? XqAppearance.dark : XqAppearance.light, p);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString(StorageKeys.appearance);
    if (a != null) {
      _appearance = XqAppearance.values.firstWhere((e) => e.name == a, orElse: () => XqAppearance.system);
      _lightPaper = _pick(prefs.getString(StorageKeys.paperLight), XqPalette.lights, XqPalette.sujian);
      _darkPaper = _pick(prefs.getString(StorageKeys.paperDark), XqPalette.darks, XqPalette.cixing);
    } else {
      final (ap, paper) = migrate(
        prefs.getString(StorageKeys.themeMode),
        explicit: prefs.getBool(StorageKeys.themeExplicit) ?? false,
      );
      _appearance = ap;
      if (paper.dark) {
        _darkPaper = paper;
      } else {
        _lightPaper = paper;
      }
      await _save(prefs);
    }
    _loaded = true;
    notifyListeners();
  }

  static XqPalette _pick(String? id, List<XqPalette> pool, XqPalette fallback) {
    final p = XqPalette.byId(id);
    return p != null && pool.contains(p) ? p : fallback;
  }

  Future<void> _save([SharedPreferences? prefs]) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setString(StorageKeys.appearance, _appearance.name);
    await sp.setString(StorageKeys.paperLight, _lightPaper.id);
    await sp.setString(StorageKeys.paperDark, _darkPaper.id);
  }

  void setAppearance(XqAppearance a, {Offset? origin}) {
    if (a == _appearance) return;
    revealOrigin = origin;
    _appearance = a;
    notifyListeners();
    _save();
  }

  /// 换纸：点哪张就用哪张。点的纸和当前深浅不同时，顺带把深浅固定过去，否则点了看不到变化。
  void setPaper(XqPalette p, {Offset? origin, bool story = false}) {
    final before = palette;
    if (p.dark) {
      _darkPaper = p;
    } else {
      _lightPaper = p;
    }
    if (p.dark != isDark) _appearance = p.dark ? XqAppearance.dark : XqAppearance.light;
    if (palette == before) return;
    revealOrigin = origin;
    storyPaper = story ? p : null;
    notifyListeners();
    _save();
  }

  /// 兼容旧调用：按 id 换纸
  void setTheme(String id) {
    final p = XqPalette.byId(id);
    if (p != null) setPaper(p);
  }

  // ── 颜色 ──

  Color get backgroundColor => palette.background;
  Color get cardColor => palette.card;
  Color get cardElevated => palette.cardElevated;
  Color get sunkenColor => palette.sunken;
  Color get frameColor => palette.frame;
  Color get borderColor => palette.border;
  Color get controlBorder => palette.controlBorder;
  Color get borderFocus => palette.borderFocus;
  Color get paperLine => palette.paperLine;
  Color get paperFiber => palette.fiber;
  Color get accentColor => palette.accent;
  Color get accentLight => palette.accentLight;
  Color get accentMuted => palette.accentMuted;
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get textTertiary => palette.textTertiary;
  Color get textOnAccent => palette.textOnAccent;
  Color get errorColor => palette.error;
  Color get successColor => palette.success;
  Color get warningColor => palette.warning;
  Color get ink => palette.ink;
  Color get inkLight => palette.inkLight;
  Color get gold => palette.gold;
  Color get sealColor => palette.seal;
  Color get surfaceAlpha => palette.accent.withAlpha(isDark ? 24 : 20);
  List<Color> get washiColors => palette.washi;
}
