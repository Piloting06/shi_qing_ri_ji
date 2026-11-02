import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'xq_colors.dart';
import 'xq_typography.dart';

/// 拾晴日记 — ThemeData 构建器
/// 统一 _build() 消除亮色/暗色重复，所有主题走同一管线
class XqTheme {
  XqTheme._();

  /// 根据模式返回对应 ThemeData
  static ThemeData forMode(String mode) {
    if (mode == 'sujian_dark') {
      return _build(
        brightness: Brightness.dark,
        overlay: SystemUiOverlayStyle.light,
        bg: XqColors.sujianDarkBackground,
        card: XqColors.sujianDarkCard,
        accent: XqColors.sujianDarkAccent,
        accentLight: XqColors.sujianDarkAccentLight,
        border: XqColors.sujianDarkBorder,
        focus: XqColors.sujianDarkBorderFocus,
        text1: XqColors.sujianDarkTextPrimary,
        text2: XqColors.sujianDarkTextSecondary,
        text3: XqColors.sujianDarkTextTertiary,
        onAccent: XqColors.sujianDarkTextOnAccent,
        error: XqColors.sujianDarkError,
      );
    }
    if (mode == 'dark') {
      return _build(
        brightness: Brightness.dark,
        overlay: SystemUiOverlayStyle.light,
        bg: XqColors.darkBackground,
        card: XqColors.darkCard,
        accent: XqColors.darkAccent,
        accentLight: XqColors.darkAccentLight,
        border: XqColors.darkBorder,
        focus: XqColors.darkBorderFocus,
        text1: XqColors.darkTextPrimary,
        text2: XqColors.darkTextSecondary,
        text3: XqColors.darkTextTertiary,
        onAccent: XqColors.darkTextOnAccent,
        error: XqColors.darkError,
      );
    }
    return _build(
      brightness: Brightness.light,
      overlay: SystemUiOverlayStyle.dark,
      bg: _bg(mode),
      card: _card(mode),
      accent: _accent(mode),
      accentLight: _accentLight(mode),
      border: _border(mode),
      focus: _focus(mode),
      text1: _textPrimary(mode),
      text2: _textSecondary(mode),
      text3: _textTertiary(mode),
      onAccent: _textOnAccent(),
      error: _error(),
    );
  }

  // ── Legacy compat ──
  static ThemeData light() => forMode('warm');
  static ThemeData dark() => forMode('dark');

  // ── Single build pipeline ──
  static ThemeData _build({
    required Brightness brightness,
    required SystemUiOverlayStyle overlay,
    required Color bg,
    required Color card,
    required Color accent,
    required Color accentLight,
    required Color border,
    required Color focus,
    required Color text1,
    required Color text2,
    required Color text3,
    required Color onAccent,
    required Color error,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? ColorScheme.dark(
            primary: accent,
            secondary: accentLight,
            surface: card,
            error: error,
            onPrimary: onAccent,
            onSecondary: text1,
            onSurface: text1,
          )
        : ColorScheme.light(
            primary: accent,
            secondary: accentLight,
            surface: card,
            error: error,
            onPrimary: onAccent,
            onSecondary: text1,
            onSurface: text1,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      fontFamily: 'LXGW WenKai',
      textTheme: TextTheme(
        displayLarge: XqTypography.displayLarge.copyWith(color: text1),
        displayMedium: XqTypography.displayMedium.copyWith(color: text1),
        displaySmall: XqTypography.displaySmall.copyWith(color: text1),
        headlineLarge: XqTypography.headlineLarge.copyWith(color: text1),
        headlineMedium: XqTypography.headlineMedium.copyWith(color: text1),
        headlineSmall: XqTypography.headlineSmall.copyWith(color: text1),
        bodyLarge: XqTypography.bodyLarge.copyWith(color: text1),
        bodyMedium: XqTypography.bodyMedium.copyWith(color: text2),
        bodySmall: XqTypography.bodySmall.copyWith(color: text3),
        labelLarge: XqTypography.labelLarge.copyWith(color: text1),
        labelMedium: XqTypography.labelMedium.copyWith(color: text2),
        labelSmall: XqTypography.labelSmall.copyWith(color: text3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: focus, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: card,
        hintStyle: XqTypography.bodyMedium.copyWith(color: text3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: XqTypography.labelLarge,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: overlay,
        titleTextStyle:
            XqTypography.headlineMedium.copyWith(color: text1),
        iconTheme: IconThemeData(color: text1),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: XqTypography.bodyMedium.copyWith(color: text1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle:
            XqTypography.headlineMedium.copyWith(color: text1),
        contentTextStyle: XqTypography.bodyMedium.copyWith(color: text2),
      ),
    );
  }

  // ── Color resolvers (light themes only) ──

  static Color _bg(String m) => switch (m) {
    'sujian' => XqColors.sujianBackground,
    'mint' => XqColors.mintBackground,
    'blush' => XqColors.blushBackground,
    _ => XqColors.sujianBackground,
  };
  static Color _card(String m) => switch (m) {
    'sujian' => XqColors.sujianCard,
    'mint' => XqColors.mintCard,
    'blush' => XqColors.blushCard,
    _ => XqColors.sujianCard,
  };
  static Color _accent(String m) => switch (m) {
    'sujian' => XqColors.sujianAccent,
    'mint' => XqColors.mintAccent,
    'blush' => XqColors.blushAccent,
    _ => XqColors.sujianAccent,
  };
  static Color _accentLight(String m) => switch (m) {
    'sujian' => XqColors.sujianAccentLight,
    'mint' => XqColors.mintAccentLight,
    'blush' => XqColors.blushAccentLight,
    _ => XqColors.sujianAccentLight,
  };
  static Color _border(String m) => switch (m) {
    'sujian' => XqColors.sujianBorder,
    'mint' => XqColors.mintBorder,
    'blush' => XqColors.blushBorder,
    _ => XqColors.sujianBorder,
  };
  static Color _focus(String m) => switch (m) {
    'sujian' => XqColors.sujianBorderFocus,
    'mint' => XqColors.mintBorderFocus,
    'blush' => XqColors.blushBorderFocus,
    _ => XqColors.sujianBorderFocus,
  };
  static Color _textPrimary(String m) => switch (m) {
    'sujian' => XqColors.sujianTextPrimary,
    'mint' => XqColors.mintTextPrimary,
    'blush' => XqColors.blushTextPrimary,
    _ => XqColors.sujianTextPrimary,
  };
  static Color _textSecondary(String m) => switch (m) {
    'sujian' => XqColors.sujianTextSecondary,
    'mint' => XqColors.mintTextSecondary,
    'blush' => XqColors.blushTextSecondary,
    _ => XqColors.sujianTextSecondary,
  };
  static Color _textTertiary(String m) => switch (m) {
    'sujian' => XqColors.sujianTextTertiary,
    'mint' => XqColors.mintTextTertiary,
    'blush' => XqColors.blushTextTertiary,
    _ => XqColors.sujianTextTertiary,
  };
  static Color _textOnAccent() => const Color(0xFFFFFFFF);
  static Color _error() => XqColors.lightError;
}
