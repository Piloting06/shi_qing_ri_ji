import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'xq_colors.dart';
import 'xq_typography.dart';
import 'xq_decorations.dart';

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
        control: XqColors.sujianDarkControlBorder,
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
        control: XqColors.sujianDarkControlBorder,
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
      control: _controlBorder(mode),
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
    required Color control,
    required Color focus,
    required Color text1,
    required Color text2,
    required Color text3,
    required Color onAccent,
    required Color error,
  }) {
    final isDark = brightness == Brightness.dark;
    final frame = isDark ? XqColors.sujianDarkFrame : XqColors.sujianFrame; // 笺框细墨线
    final paperSide = BorderSide(color: frame, width: 0.6);
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
      // 界面走系统黑体；宋体只在 Display/Headline，楷体只在内容层（ADR-0004）
      splashFactory: NoSplash.splashFactory,
      // 转场：新页像一张纸从右侧铺上来，下层略退（并支持右滑返回）
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withAlpha(50),
        selectionHandleColor: accent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: accent,
        disabledColor: Colors.transparent,
        side: BorderSide(color: frame, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusSmall)),
        labelStyle: XqTypography.bodyMedium.copyWith(color: text2, fontSize: 13),
        secondaryLabelStyle: XqTypography.bodyMedium.copyWith(color: onAccent, fontSize: 13),
        showCheckmark: false,
        checkmarkColor: onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onAccent : control),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : card),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : control),
        trackOutlineWidth: const WidgetStatePropertyAll(0.8),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: accent.withAlpha(20),
        trackHeight: 2,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: bg,
        headerForegroundColor: text1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusSheet), side: paperSide),
        dayShape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusControl))),
        todayBorder: BorderSide(color: accent, width: 0.8),
        dividerColor: border,
      ),
      highlightColor: accent.withAlpha(14),
      iconTheme: IconThemeData(color: text2, size: 22),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border,
        circularTrackColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: text2,
        textColor: text1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        minLeadingWidth: 24,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        modalBarrierColor: Colors.black.withAlpha(isDark ? 140 : 70),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false, // 各弹层自带拖拽条，主题不重复加
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(XqDecorations.radiusSheet)),
          side: paperSide,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XqDecorations.radiusControl),
          side: BorderSide(color: border, width: 0.5),
        ),
        textStyle: XqTypography.bodyLarge.copyWith(color: text1),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: border,
          disabledForegroundColor: text3,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusControl)),
          textStyle: XqTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: control, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusControl)),
          textStyle: XqTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusControl)),
          textStyle: XqTypography.labelLarge,
        ),
      ),
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
          borderRadius: BorderRadius.circular(XqDecorations.radiusControl),
          borderSide: BorderSide(color: control),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XqDecorations.radiusControl),
          borderSide: BorderSide(color: control.withAlpha(150), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XqDecorations.radiusControl),
          borderSide: BorderSide(color: focus, width: 1.2),
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
          disabledBackgroundColor: border,
          disabledForegroundColor: text3,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XqDecorations.radiusControl),
          ),
          textStyle: XqTypography.button,
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
        contentTextStyle: XqTypography.bodyMedium.copyWith(color: text1, fontSize: 14),
        actionTextColor: accent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusControl), side: paperSide),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XqDecorations.radiusSheet), side: paperSide),
        titleTextStyle:
            XqTypography.headlineMedium.copyWith(color: text1),
        contentTextStyle: XqTypography.bodyMedium.copyWith(color: text2),
      ),
    );
  }

  // ── Color resolvers (light themes only) ──

  static Color _bg(String m) => switch (m) {
    'sujian' => XqColors.sujianBackground,
    'warm' => XqColors.lightBackground,
    'mint' => XqColors.mintBackground,
    'blush' => XqColors.blushBackground,
    _ => XqColors.sujianBackground,
  };
  static Color _card(String m) => switch (m) {
    'sujian' => XqColors.sujianCard,
    'warm' => XqColors.lightCard,
    'mint' => XqColors.mintCard,
    'blush' => XqColors.blushCard,
    _ => XqColors.sujianCard,
  };
  static Color _accent(String m) => switch (m) {
    'sujian' => XqColors.sujianAccent,
    'warm' => XqColors.lightAccent,
    'mint' => XqColors.mintAccent,
    'blush' => XqColors.blushAccent,
    _ => XqColors.sujianAccent,
  };
  static Color _accentLight(String m) => switch (m) {
    'sujian' => XqColors.sujianAccentLight,
    'warm' => XqColors.lightAccentLight,
    'mint' => XqColors.mintAccentLight,
    'blush' => XqColors.blushAccentLight,
    _ => XqColors.sujianAccentLight,
  };
  static Color _controlBorder(String m) => switch (m) {
    'sujian' => XqColors.sujianControlBorder,
    'warm' => XqColors.lightTextTertiary,
    'mint' => XqColors.mintTextTertiary,
    'blush' => XqColors.blushTextTertiary,
    _ => XqColors.lightTextTertiary,
  };
  static Color _border(String m) => switch (m) {
    'sujian' => XqColors.sujianBorder,
    'warm' => XqColors.lightBorder,
    'mint' => XqColors.mintBorder,
    'blush' => XqColors.blushBorder,
    _ => XqColors.sujianBorder,
  };
  static Color _focus(String m) => switch (m) {
    'sujian' => XqColors.sujianBorderFocus,
    'warm' => XqColors.lightBorderFocus,
    'mint' => XqColors.mintBorderFocus,
    'blush' => XqColors.blushBorderFocus,
    _ => XqColors.sujianBorderFocus,
  };
  static Color _textPrimary(String m) => switch (m) {
    'sujian' => XqColors.sujianTextPrimary,
    'warm' => XqColors.lightTextPrimary,
    'mint' => XqColors.mintTextPrimary,
    'blush' => XqColors.blushTextPrimary,
    _ => XqColors.sujianTextPrimary,
  };
  static Color _textSecondary(String m) => switch (m) {
    'sujian' => XqColors.sujianTextSecondary,
    'warm' => XqColors.lightTextSecondary,
    'mint' => XqColors.mintTextSecondary,
    'blush' => XqColors.blushTextSecondary,
    _ => XqColors.sujianTextSecondary,
  };
  static Color _textTertiary(String m) => switch (m) {
    'sujian' => XqColors.sujianTextTertiary,
    'warm' => XqColors.lightTextTertiary,
    'mint' => XqColors.mintTextTertiary,
    'blush' => XqColors.blushTextTertiary,
    _ => XqColors.sujianTextTertiary,
  };
  static Color _textOnAccent() => const Color(0xFFFFFFFF);
  static Color _error() => XqColors.lightError;
}
