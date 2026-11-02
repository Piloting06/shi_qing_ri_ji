import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/widgets/jiangnan_scene.dart';

void main() {
  // 回归：首页山体曾因 Paint 未上色整片渲染为纯黑。
  // 黄金基准锁定烟雨场景的完整渲染——黑山/丢雾带/丢石桥都会 diff 失败。
  // 基准图更新：flutter test --update-goldens
  Widget scene({int hour = 14}) => RepaintBoundary(
        child: CustomPaint(
          size: const Size(400, 800),
          painter: JiangnanScenePainter(
            paper: const Color(0xFFEFEFE9),
            accent: const Color(0xFF3D5A66),
            ink: const Color(0xFF34393C),
            surface: const Color(0xFFF7F7F2),
            hour: hour,
            seed: 9,
          ),
        ),
      );

  testWidgets('烟雨场景黄金基准（防黑山/丢层回归）', (tester) async {
    await tester.pumpWidget(scene());
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/jiangnan_scene_day.png'),
    );
  });

  testWidgets('夜間淡月黄金基准', (tester) async {
    await tester.pumpWidget(scene(hour: 23));
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/jiangnan_scene_night.png'),
    );
  });
}
