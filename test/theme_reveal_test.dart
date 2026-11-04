import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xin_qing_ri_ji/stores/theme_state.dart';
import 'package:xin_qing_ri_ji/theme/xq_palette.dart';
import 'package:xin_qing_ri_ji/widgets/xq/xq_theme_reveal.dart';

/// 换纸过渡：点了纸才盖一层旧画面，动画结束后撤掉（不残留、不泄漏图片）；启动读偏好那一下不做动画。
void main() {
  Finder overlay() => find.byKey(XqThemeReveal.overlayKey);

  Future<ThemeState> boot(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final theme = ThemeState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: theme,
        child: MaterialApp(
          builder: (context, child) => XqThemeReveal(child: child!),
          home: Builder(builder: (context) => ColoredBox(color: context.watch<ThemeState>().backgroundColor)),
        ),
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    return theme;
  }

  testWidgets('启动读出偏好不触发过渡', (tester) async {
    final theme = await boot(tester, {'appearance': 'dark', 'paperDark': 'dark'});
    expect(theme.loaded, isTrue);
    expect(theme.palette, XqPalette.dai);
    expect(overlay(), findsNothing);
  });

  testWidgets('换纸：盖上旧画面 → 晕开 → 撤掉', (tester) async {
    final theme = await boot(tester, {});
    expect(overlay(), findsNothing);
    theme.setPaper(XqPalette.warm, origin: const Offset(100, 300));
    await tester.pump();
    expect(overlay(), findsOneWidget);
    expect(theme.palette, XqPalette.warm);
    await tester.pump(const Duration(milliseconds: 400));
    expect(overlay(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(overlay(), findsNothing);
  });

  testWidgets('点深色纸会把深浅固定到夜里；同一张纸再点不动', (tester) async {
    final theme = await boot(tester, {'appearance': 'light'});
    theme.setPaper(XqPalette.dai, origin: Offset.zero);
    expect(theme.appearance, XqAppearance.dark);
    expect(theme.darkPaper, XqPalette.dai);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    theme.setPaper(XqPalette.dai, origin: Offset.zero);
    await tester.pump();
    expect(overlay(), findsNothing);
  });
}
