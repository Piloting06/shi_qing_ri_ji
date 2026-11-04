import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 江南烟雨全景（首页背景，分层纵深）：
/// 纸纹 → 天光/淡月 → 三层黛青山 → 雾带遮山腰 → 石桥一座。
/// 颜色全部取主题 Token；远山以黛青、近山以墨，透明度分层出空气透视。
class JiangnanScenePainter extends CustomPainter {
  final Color paper; // 瓦白底
  final Color accent; // 黛青
  final Color ink; // 墨
  final Color surface; // 雾带用（比纸浅一层）
  final int hour; // 时辰：决定淡月或日晕
  final int seed;

  JiangnanScenePainter({
    required this.paper,
    required this.accent,
    required this.ink,
    required this.surface,
    required this.hour,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    // ── 纸底：场景自含，所见即所得 ──
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);

    // ── 纸纹：极淡的飞点（alpha≈4，阅读区不受干扰）──
    final grain = Paint()..color = ink.withAlpha(5);
    for (int i = 0; i < 130; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 0.9 + 0.2,
        grain,
      );
    }

    // ── 天光：夜里一枚淡月，白天一痕日晕（右上角，含柔光晕）──
    final isNight = hour >= 19 || hour < 5;
    final orbC = Offset(size.width * 0.82, size.height * 0.16);
    final orbR = size.shortestSide * (isNight ? 0.045 : 0.055);
    canvas.drawCircle(
      orbC,
      orbR * 2.6,
      Paint()
        ..shader = RadialGradient(colors: [
          (isNight ? ink : accent).withAlpha(isNight ? 26 : 16),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: orbC, radius: orbR * 2.6)),
    );
    if (isNight) {
      // 淡月（弯月：两圆相减的近似——画满月再用底色圆偏移遮出月牙）
      canvas.drawCircle(orbC, orbR, Paint()..color = ink.withAlpha(38));
      canvas.drawCircle(
        orbC + Offset(orbR * 0.42, -orbR * 0.18),
        orbR * 0.92,
        Paint()..color = paper,
      );
    } else {
      canvas.drawCircle(orbC, orbR * 0.72, Paint()..color = accent.withAlpha(14));
    }

    // ── 三层山：远(黛青淡) → 中(黛青) → 近(墨)，高度递增、透明度递增 ──
    final h = size.height;
    _paintRidge(canvas, size, rng, baseY: h * 0.46, amp: h * 0.10,
        color: accent.withAlpha(26), segments: 3);
    _paintRidge(canvas, size, rng, baseY: h * 0.56, amp: h * 0.12,
        color: accent.withAlpha(42), segments: 4);

    // ── 石桥一座：跨在中山与近山之间的水口（墨色剪影）──
    _bridge(canvas, size,
        cx: size.width * 0.68, deckY: h * 0.72, w: size.width * 0.22,
        color: ink.withAlpha(120));

    _paintRidge(canvas, size, rng, baseY: h * 0.70, amp: h * 0.14,
        color: ink.withAlpha(56), segments: 3);

    // ── 雾带：横向渐变 + 上下羽化（sin 缘），无矩形硬边 ──
    _mist(canvas, size, h * 0.50, h * 0.14, 130);
    _mist(canvas, size, h * 0.64, h * 0.16, 100);

    // ── 水口：山脚一条静水（比纸深半档的水平面）──
    final water = Rect.fromLTWH(0, h * 0.78, size.width, h * 0.22);
    canvas.drawRect(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withAlpha(14), accent.withAlpha(4)],
        ).createShader(water),
    );
  }

  void _paintRidge(Canvas canvas, Size size, math.Random rng,
      {required double baseY, required double amp, required Color color, required int segments}) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseY);
    for (int i = 0; i < segments; i++) {
      final x0 = size.width * i / segments;
      final x1 = size.width * (i + 1) / segments;
      final peak = baseY - amp * (0.55 + rng.nextDouble() * 0.6);
      path.quadraticBezierTo((x0 + x1) / 2, peak, x1, baseY + rng.nextDouble() * amp * 0.2);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// 柔雾：横向中间浓两端散，纵向 sin 羽化上下缘
  void _mist(Canvas canvas, Size size, double y, double hh, int alpha) {
    const slices = 48;
    final sh = hh / slices;
    for (int i = 0; i < slices; i++) {
      final t = (i + 0.5) / slices;
      final ramp = math.sin(t * math.pi);
      final rect = Rect.fromLTWH(0, y + i * sh, size.width, sh + 0.6);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              surface.withAlpha(0),
              surface.withAlpha((alpha * ramp).round()),
              surface.withAlpha(0),
            ],
          ).createShader(rect),
      );
    }
  }

  void _bridge(Canvas canvas, Size size,
      {required double cx, required double deckY, required double w, required Color color}) {
    final paint = Paint()..color = color;
    // 桥面
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, deckY, w, 5),
        const Radius.circular(2),
      ),
      paint,
    );
    // 石拱（半圆环）
    final archR = w * 0.30;
    final archC = Offset(cx, deckY + 2);
    canvas.drawArc(
      Rect.fromCircle(center: archC, radius: archR),
      0, math.pi, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 4,
    );
    // 桥墩两根
    canvas.drawLine(Offset(cx - w / 2 + 3, deckY + 4), Offset(cx - w / 2 + 3, deckY + 14), paint..strokeWidth = 3);
    canvas.drawLine(Offset(cx + w / 2 - 3, deckY + 4), Offset(cx + w / 2 - 3, deckY + 14), paint..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant JiangnanScenePainter old) =>
      old.paper != paper || old.accent != accent || old.ink != ink || old.seed != seed;
}
