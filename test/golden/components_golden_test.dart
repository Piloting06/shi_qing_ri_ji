@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/theme/xq_palette.dart';
import 'package:xin_qing_ri_ji/theme/xq_typography.dart';
import 'package:xin_qing_ri_ji/widgets/mood_card/mood_card_data.dart';
import 'package:xin_qing_ri_ji/widgets/mood_card/mood_card_registry.dart';
import 'package:xin_qing_ri_ji/widgets/xq/xq_icons.dart';
import 'package:xin_qing_ri_ji/widgets/xq/xq_kit.dart';
import 'package:xin_qing_ri_ji/widgets/xq/xq_paper.dart';

/// 截图对比：只锁和日期无关的部分（全部卡片模板、图标、印、颜料、四张纸）。
/// 整页跟着今天的天色和日期变，不适合做像素对比。
/// 只在 macOS 上比对（字体光栅化跨平台不一致）。更新基准：
///   flutter test test/golden --update-goldens
const _data = MoodCardData(
  dateText: '2026年11月5日 星期四',
  rawDate: '2026-11-05',
  moodScore: 7,
  moodLabel: '期待',
  bodyText: '周末要去看外婆。她说院子里的桂花还没落完，让我早点回去。',
  tags: ['家人'],
  username: '晚风',
  watermark: 'cn',
  weatherText: '小雨',
  cityName: '杭州',
  temperature: '16°',
  square: false,
  streakDays: 5,
  week: [
    MoodDay(label: '四', color: 0xFFCC7550, mood: '期待', isToday: true),
    MoodDay(label: '三', color: 0xFF7A7871, mood: '疲惫', isToday: false),
    MoodDay(label: '二', color: 0xFFC9982A, mood: '开心', isToday: false),
    MoodDay(label: '一', isToday: false),
    MoodDay(label: '日', color: 0xFFCC7550, mood: '期待', isToday: false),
    MoodDay(label: '六', isToday: false),
    MoodDay(label: '五', color: 0xFF5A9480, mood: '平静', isToday: false),
  ],
);

Future<void> _font(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final a in assets) {
    loader.addFont(rootBundle.load(a));
  }
  await loader.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}

void main() {
  final skip = !Platform.isMacOS;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _font('Display', ['assets/fonts/ZhuqueFangsong-sub.ttf']);
    await _font('LXGW WenKai', ['assets/fonts/LXGWWenKai-Regular.ttf']);
    await _font('SerifSC', ['assets/fonts/NotoSerifSC-600.otf']);
    // 界面黑体在测试里没有系统字体，用楷体顶上（只为稳定，不代表真机效果）
    await _font('Roboto', ['assets/fonts/LXGWWenKai-Regular.ttf']);
    await XqPaper.ensureLoaded();
    // 册页 / 邮票里的点景线稿走 XqPaper.loadImage 缓存：必须在真实异步里先载好，
    // 否则第一次在 build（假异步）里发起的加载永远不完成，又被缓存住
    await XqPaper.loadImage('assets/motifs/boat.png');
    await XqPaper.loadImage('assets/motifs/sail.png');
  });

  Future<void> shoot(WidgetTester tester, Size size, Widget child, String name) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFE6E0D3),
          body: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: XqTypography.content, fontFamilyFallback: XqTypography.contentFallback),
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Scaffold));
      await precacheImage(const AssetImage(XqPaper.asset), ctx);
      await precacheImage(const AssetImage('assets/motifs/branch.png'), ctx);
    });
    await _settle(tester);
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('全部卡片模板（横幅）', (tester) async {
    await shoot(
      tester,
      const Size(760, 1260),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in moodCardTemplates) SizedBox(width: 362, child: t.buildCard(_data)),
          ],
        ),
      ),
      'cards',
    );
  }, skip: skip);

  testWidgets('图标、印、颜料、六张纸', (tester) async {
    await shoot(
      tester,
      const Size(400, 420),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final i in XqIcons.values) XqIcon(i, size: 22, color: const Color(0xFF22211C))],
            ),
            const SizedBox(height: 14),
            const Row(children: [
              XqSeal(char: '晴', color: Color(0xFFAE3624), size: 40),
              SizedBox(width: 10),
              XqSeal(char: '拾晴', color: Color(0xFFAE3624), size: 40, style: XqSealStyle.bai),
              SizedBox(width: 10),
              XqSeal(char: '十五日', color: Color(0xFFAE3624), size: 40, style: XqSealStyle.bai),
              SizedBox(width: 10),
              XqSeal(char: '拾晴日记', color: Color(0xFFAE3624), size: 40),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              for (var s = 1; s <= 8; s++) ...[
                XqPigmentDab(color: Color(const [0, 0xFFC9982A, 0xFF5A9480, 0xFF3F5A7E, 0xFFA63A4C, 0xFF96633A, 0xFF7A7871, 0xFFCC7550, 0xFF9A7A98][s]), size: 28, seed: s),
                const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 14),
            Row(children: [
              for (final p in XqPalette.all)
                Container(
                  width: 52,
                  height: 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: p.card,
                    border: Border.all(color: p.frame, width: 0.6),
                    image: XqPaper.grain(p.fiber, strength: p.dark ? 0.6 : 0.8),
                  ),
                  alignment: Alignment.center,
                  child: Text(p.name, style: TextStyle(fontFamily: 'Display', fontSize: 14, color: p.textPrimary)),
                ),
            ]),
          ],
        ),
      ),
      'kit',
    );
  }, skip: skip);
}
