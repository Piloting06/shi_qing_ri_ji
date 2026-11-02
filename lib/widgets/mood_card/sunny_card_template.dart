import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import 'mood_card_data.dart';

/// 晴收集：卡片随当天真实天气自动换肤（晴/云/阴雾/雨/雪），
/// 天气可被用户在编辑面板手动覆盖（override 后配色与场景同步切换）。
class SunnyCardTemplate {
  SunnyCardTemplate._();

  static ({Color bg, Color accent, Color text}) paletteFor(String? weather) {
    final w = weather ?? '';
    if (w.contains('雪')) {
      return (
        bg: const Color(0xFFEAF2F8),
        accent: const Color(0xFF6E9EC4),
        text: const Color(0xFF24384A)
      );
    }
    if (w.contains('雨') || w.contains('雷') || w.contains('阵雨')) {
      return (
        bg: const Color(0xFFE2EAF1),
        accent: const Color(0xFF4F7396),
        text: const Color(0xFF1F3244)
      );
    }
    if (w.contains('阴') || w.contains('雾') || w.contains('霾')) {
      return (
        bg: const Color(0xFFEAECEF),
        accent: const Color(0xFF7E8C96),
        text: const Color(0xFF2C343A)
      );
    }
    if (w.contains('云')) {
      return (
        bg: const Color(0xFFF0F3EE),
        accent: const Color(0xFF6E8F5E),
        text: const Color(0xFF2C3A26)
      );
    }
    return (
      bg: const Color(0xFFFFF6DF),
      accent: const Color(0xFFDE9A26),
      text: const Color(0xFF4A3312)
    );
  }

  static String _sceneType(String? w) {
    final s = w ?? '';
    if (s.contains('雪')) return 'snow';
    if (s.contains('雨') || s.contains('雷') || s.contains('阵雨')) return 'rain';
    if (s.contains('阴') || s.contains('雾') || s.contains('霾')) return 'haze';
    if (s.contains('云')) return 'cloud';
    return 'sun';
  }

  static Widget build(MoodCardData data) {
    final p = paletteFor(data.weatherText);
    final br = data.square ? 0.0 : 20.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(br),
        border: Border.all(color: p.accent.withAlpha(30), width: 0.5),
        boxShadow: XqDecorations.shadowStrong(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: Stack(
          children: [
            SizedBox(
              height: data.height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          data.dateText,
                          style: TextStyle(
                            color: p.text.withAlpha(140),
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: p.accent.withAlpha(18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${data.weatherText ?? ''} · 晴收集',
                            style: TextStyle(
                              color: p.accent.withAlpha(190),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          data.moodEmoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.moodLabel,
                                style: XqTypography.handwrittenBody.copyWith(
                                  color: p.text,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data.moodEn,
                                style: TextStyle(
                                  color: p.accent.withAlpha(150),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data.temperature != null)
                          Text(
                            data.temperature!,
                            style: TextStyle(
                              color: p.accent.withAlpha(140),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          data.bodyText.isNotEmpty ? data.bodyText : '写点什么吧',
                          style: XqTypography.handwrittenBody.copyWith(
                            color: data.bodyText.isNotEmpty
                                ? p.text
                                : p.text.withAlpha(60),
                            fontSize: (data.bodyText.isNotEmpty ? 14.5 : 14.0) * data.bodyScale,
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (data.tags.isNotEmpty)
                          Expanded(
                            child: Text(
                              data.tags.take(3).join(' · '),
                              style: TextStyle(
                                color: p.accent.withAlpha(120),
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (data.tags.isEmpty) const Spacer(),
                        Text(
                          watermarkTextFor(data.watermark),
                          style: TextStyle(
                            color: p.accent.withAlpha(110),
                            fontSize: 8.2,
                            fontWeight: FontWeight.w600,
                            letterSpacing:
                                data.watermark == 'sqrj' ? 1.5 : 1.15,
                          ),
                        ),
                        if (data.username.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            data.username,
                            style: TextStyle(
                              color: p.accent.withAlpha(90),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _WeatherScenePainter(
                    scene: _sceneType(data.weatherText),
                    accent: p.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 天气场景画笔：按 scene 绘制有构图的矢量场景（全部程序化绘制，3x 导出不糊）
class _WeatherScenePainter extends CustomPainter {
  final String scene; // sun | cloud | haze | rain | snow
  final Color accent;
  _WeatherScenePainter({required this.scene, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    switch (scene) {
      case 'rain':
        _paintRain(canvas, size);
      case 'snow':
        _paintSnow(canvas, size);
      case 'haze':
        _paintHaze(canvas, size);
      case 'cloud':
        _paintCloud(canvas, size);
      default:
        _paintSun(canvas, size);
    }
  }

  // ── 晴：渐变光晕太阳 + 锥形光芒环 + 浮光尘 ──
  void _paintSun(Canvas canvas, Size size) {
    final center = Offset(size.width - 44, 40);

    // 外圈光晕（径向渐变，往外融进背景）
    canvas.drawCircle(
      center,
      44,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withAlpha(40),
            accent.withAlpha(12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 44)),
    );

    // 太阳本体（立体感：亮心 + 描边）
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [accent.withAlpha(140), accent.withAlpha(60)],
        ).createShader(Rect.fromCircle(center: center, radius: 15)),
    );
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withAlpha(80),
    );

    // 12 道锥形光芒（长短相间）
    final ray = Path();
    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final inner = 19.0;
      final outer = i.isEven ? 30.0 : 25.0;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final perp = Offset(-dir.dy, dir.dx);
      final base = center + dir * inner;
      final tip = center + dir * outer;
      ray.moveTo(base.dx + perp.dx * 1.4, base.dy + perp.dy * 1.4);
      ray.lineTo(tip.dx, tip.dy);
      ray.lineTo(base.dx - perp.dx * 1.4, base.dy - perp.dy * 1.4);
      ray.close();
    }
    canvas.drawPath(ray, Paint()..color = accent.withAlpha(70));

    // 浮光尘
    final rng = math.Random(3);
    final mote = Paint()..color = accent.withAlpha(50);
    for (int i = 0; i < 12; i++) {
      final x = rng.nextDouble() * size.width;
      final y = size.height * 0.25 + rng.nextDouble() * size.height * 0.6;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.2 + 0.4, mote);
    }
  }

  // ── 多云：双层云团（带底部阴影层次）+ 远处小云 ──
  void _paintCloud(Canvas canvas, Size size) {
    final shadow = Paint()..color = accent.withAlpha(16);
    final body = Paint()..color = accent.withAlpha(30);
    final bodySoft = Paint()..color = accent.withAlpha(20);

    void cloud(Offset c, double s, Paint paint) {
      canvas.drawCircle(c, 11 * s, paint);
      canvas.drawCircle(c + Offset(14 * s, 3 * s), 8.5 * s, paint);
      canvas.drawCircle(c + Offset(-13 * s, 4 * s), 7.5 * s, paint);
      canvas.drawCircle(c + Offset(3 * s, 7 * s), 9.5 * s, paint);
      // 云底阴影
      canvas.drawCircle(c + Offset(2 * s, 10 * s), 8 * s, shadow);
    }

    cloud(Offset(size.width - 46, 34), 1.5, body);
    cloud(Offset(size.width - 104, 20), 0.9, bodySoft);
  }

  // ── 阴/雾：层叠渐变雾带 + 云后隐约的太阳轮廓 ──
  void _paintHaze(Canvas canvas, Size size) {
    // 隐约的太阳（被雾遮住的感觉）
    canvas.drawCircle(
      Offset(size.width - 40, 34),
      13,
      Paint()..color = Colors.white.withAlpha(60),
    );

    // 三条雾带，透明度逐层变化、两端渐隐
    final rects = [
      Rect.fromLTWH(size.width * 0.42, 22, size.width * 0.52, 7),
      Rect.fromLTWH(size.width * 0.50, 36, size.width * 0.44, 6),
      Rect.fromLTWH(size.width * 0.36, 50, size.width * 0.58, 6),
    ];
    for (int i = 0; i < rects.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[i], const Radius.circular(4)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              accent.withAlpha(26 + i * 6),
              Colors.transparent,
            ],
          ).createShader(rects[i]),
      );
    }
  }

  // ── 雨：雨云 + 斜雨丝（疏密两层）+ 底部涟漪 ──
  void _paintRain(Canvas canvas, Size size) {
    final cloud = Paint()..color = accent.withAlpha(34);
    final cloudShadow = Paint()..color = accent.withAlpha(18);
    final cx = size.width - 46;
    final cy = 34.0;

    // 雨云（双层）
    canvas.drawCircle(Offset(cx, cy), 13, cloud);
    canvas.drawCircle(Offset(cx + 15, cy + 3), 9.5, cloud);
    canvas.drawCircle(Offset(cx - 14, cy + 4), 8.5, cloud);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 1, cy + 9), width: 36, height: 10),
      cloudShadow,
    );

    // 雨丝：近处粗密、远处细疏
    final rng = math.Random(7);
    final near = Paint()
      ..color = accent.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final far = Paint()
      ..color = accent.withAlpha(38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = 40 + rng.nextDouble() * (size.height - 52);
      final len = 7 + rng.nextDouble() * 9;
      final p = i % 3 == 0 ? near : far;
      canvas.drawLine(Offset(x, y), Offset(x - 2.5, y + len), p);
    }

    // 底部涟漪（两条椭圆弧）
    final ripple = Paint()
      ..color = accent.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height - 14),
        width: 34,
        height: 7,
      ),
      ripple,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.26, size.height - 11),
        width: 20,
        height: 4.5,
      ),
      ripple,
    );
  }

  // ── 雪：云 + 六瓣雪花（两种尺寸）+ 飘雪点 ──
  void _paintSnow(Canvas canvas, Size size) {
    final cloud = Paint()..color = accent.withAlpha(30);
    final cx = size.width - 46;
    final cy = 32.0;
    canvas.drawCircle(Offset(cx, cy), 12, cloud);
    canvas.drawCircle(Offset(cx + 14, cy + 3), 9, cloud);
    canvas.drawCircle(Offset(cx - 13, cy + 4), 8, cloud);

    // 六瓣雪花
    void flake(Offset c, double r, double alpha) {
      final spoke = Paint()
        ..color = accent.withAlpha(alpha.toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        final dir = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(c, c + dir * r, spoke);
        // 枝杈
        final tick = dir * (r * 0.45);
        final perp = Offset(-dir.dy, dir.dx) * (r * 0.22);
        canvas.drawLine(c + tick, c + tick + perp, spoke);
        canvas.drawLine(c + tick, c + tick - perp, spoke);
      }
    }

    flake(Offset(size.width * 0.62, 52), 6, 90);
    flake(Offset(size.width * 0.82, 96), 4.5, 70);
    flake(Offset(size.width * 0.5, 132), 3.5, 55);

    // 飘雪点
    final rng = math.Random(11);
    final dot = Paint()..color = accent.withAlpha(70);
    for (int i = 0; i < 22; i++) {
      final x = rng.nextDouble() * size.width;
      final y = 20 + rng.nextDouble() * (size.height - 32);
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.5 + 0.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherScenePainter old) =>
      old.scene != scene || old.accent != accent;
}
