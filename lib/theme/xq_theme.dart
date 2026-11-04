import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'xq_palette.dart';
import 'xq_typography.dart';
import 'xq_decorations.dart';

/// 拾晴日记 — ThemeData 构建器
/// 统一 _build() 消除亮色/暗色重复，所有主题走同一管线
class XqTheme {
  XqTheme._();

  /// 按纸 id 取 ThemeData（找不到回退素笺）
  static ThemeData forMode(String mode) => forPalette(XqPalette.byId(mode) ?? XqPalette.sujian);

  static ThemeData forPalette(XqPalette p) => _build(
        brightness: p.dark ? Brightness.dark : Brightness.light,
        overlay: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        bg: p.background,
        card: p.card,
        accent: p.accent,
        accentLight: p.accentLight,
        border: p.border,
        frame: p.frame,
        control: p.controlBorder,
        focus: p.borderFocus,
        text1: p.textPrimary,
        text2: p.textSecondary,
        text3: p.textTertiary,
        onAccent: p.textOnAccent,
        error: p.error,
      );

  // ── Single build pipeline ──
  static ThemeData _build({
    required Brightness brightness,
    required SystemUiOverlayStyle overlay,
    required Color bg,
    required Color card,
    required Color accent,
    required Color accentLight,
    required Color border,
    required Color frame,
    required Color control,
    required Color focus,
    required Color text1,
    required Color text2,
    required Color text3,
    required Color onAccent,
    required Color error,
  }) {
    final isDark = brightness == Brightness.dark;
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
}
