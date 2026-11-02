import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_paper_textures.dart';
import '../../theme/xq_typography.dart';
import 'mood_card_data.dart';

/// 经典手账笔记版式（原 warm/dark/mint/blush 四套配色共用一个版式）
class NoteCardTemplate {
  NoteCardTemplate._();

  static Color bgColor(String style) => switch (style) {
    'dark' => const Color(0xFF0E1222),
    'mint' => const Color(0xFFDDEBE3),
    'blush' => const Color(0xFFF2DED8),
    _ => const Color(0xFFFAF4EC),
  };

  static Color accentColor(String style) => switch (style) {
    'dark' => const Color(0xFFB9B8FF),
    'mint' => const Color(0xFF4D8C7A),
    'blush' => const Color(0xFFC4707A),
    _ => const Color(0xFFB8782C),
  };

  static Color textColor(String style) => style == 'dark'
      ? const Color(0xFFF4F0E7)
      : const Color(0xFF2F2118);

  static Widget build(MoodCardData data, String style) {
    final hasWeather =
        data.weatherText != null && data.weatherText!.isNotEmpty;
    final accent = accentColor(style);
    final textColor = NoteCardTemplate.textColor(style);
    final br = data.square ? 0.0 : 20.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor(style),
        borderRadius: BorderRadius.circular(br),
        border: Border.all(
          color: accent.withAlpha(style == 'dark' ? 34 : 22),
          width: 0.5,
        ),
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
                            color: textColor.withAlpha(140),
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    if (hasWeather) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.wb_sunny_outlined,
                            size: 9,
                            color: accent.withAlpha(150),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${data.weatherText}${data.cityName != null ? "  ${data.cityName}" : ""}${data.temperature != null ? " · ${data.temperature}" : ""}',
                              style: TextStyle(
                                color: textColor.withAlpha(150),
                                fontSize: 9.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(style == 'dark' ? 24 : 16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withAlpha(30),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'MOOD',
                            style: TextStyle(
                              color: accent.withAlpha(145),
                              fontSize: 7.2,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          data.moodEn,
                          style: TextStyle(
                            color: accent.withAlpha(118),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: LinedPaperPainter(
                                lineColor: accent.withAlpha(
                                  style == 'dark' ? 18 : 30,
                                ),
                                lineSpacing: 28,
                                marginLeft: 0,
                                showMarginLine: false,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2, left: 4),
                            child: Text(
                              data.bodyText.isNotEmpty
                                  ? data.bodyText
                                  : '写点什么吧',
                              textAlign: TextAlign.left,
                              style: XqTypography.handwrittenBody.copyWith(
                                color: data.bodyText.isNotEmpty
                                    ? textColor
                                    : textColor.withAlpha(60),
                                fontSize: (data.bodyText.isNotEmpty ? 15.0 : 14.0) * data.bodyScale,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (data.tags.isNotEmpty)
                          Expanded(
                            child: Text(
                              data.tags.take(3).join(' · '),
                              style: TextStyle(
                                color: accent.withAlpha(96),
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
                            color: accent.withAlpha(82),
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
                              color: accent.withAlpha(70),
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
            if (style == 'warm') const _WarmOverlay(),
            if (style == 'dark') const _DarkOverlay(),
            if (style == 'mint') const _MintOverlay(),
            if (style == 'blush') _BlushOverlay(accent: accent),
          ],
        ),
      ),
    );
  }
}

// ── Theme overlays（自 mood_card_maker.dart 原样迁移）──

class _WarmOverlay extends StatelessWidget {
  const _WarmOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _PaperGrainPainter())),
            Positioned.fill(child: CustomPaint(painter: _SunlitMarkPainter())),
          ],
        ),
      ),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = const Color(0xFFB8782C).withAlpha(6);
    for (int i = 0; i < 200; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 0.8 + 0.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SunlitMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = const Color(0xFFE7B45C).withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width - 34, 34),
          radius: 28.0 + i * 10,
        ),
        math.pi * 0.6,
        math.pi * 0.8,
        false,
        glow,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DarkOverlay extends StatelessWidget {
  const _DarkOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.82),
                    radius: 1.15,
                    colors: [
                      const Color(0xFFFFD54F).withAlpha(12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _StarDotsPainter())),
            Positioned.fill(
              child: CustomPaint(painter: _ConstellationPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(123);
    final paint = Paint()..color = Colors.white.withAlpha(24);
    for (int i = 0; i < 42; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.72;
      final r = rng.nextDouble() * 0.6 + 0.2;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width - 88, 38),
      Offset(size.width - 64, 52),
      Offset(size.width - 42, 34),
    ];
    final line = Paint()
      ..color = Colors.white.withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final dot = Paint()..color = Colors.white.withAlpha(38);
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], line);
    }
    for (final p in points) {
      canvas.drawCircle(p, 1.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MintOverlay extends StatelessWidget {
  const _MintOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _BotanicalLinePainter()),
      ),
    );
  }
}

class _BotanicalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4D8C7A).withAlpha(34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    final stem = Path()
      ..moveTo(28, size.height - 24)
      ..quadraticBezierTo(34, size.height - 62, 22, size.height - 96);
    canvas.drawPath(stem, paint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(32, size.height - 62),
        width: 18,
        height: 8,
      ),
      math.pi,
      math.pi,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(20, size.height - 82),
        width: 16,
        height: 7,
      ),
      0,
      math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlushOverlay extends StatelessWidget {
  final Color accent;
  const _BlushOverlay({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _VelvetNoisePainter(accent: accent)),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _PostmarkPainter(accent: accent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VelvetNoisePainter extends CustomPainter {
  final Color accent;
  _VelvetNoisePainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(87);
    final area = size.width * size.height;
    final count = (area * 0.08).toInt();
    for (int i = 0; i < count; i++) {
      if (rng.nextDouble() > 0.5) continue;
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = accent.withAlpha(3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PostmarkPainter extends CustomPainter {
  final Color accent;
  _PostmarkPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final center = Offset(size.width - 34, size.height - 34);
    canvas.drawCircle(center, 18, paint);
    canvas.drawLine(
      Offset(center.dx - 24, center.dy - 4),
      Offset(center.dx + 24, center.dy - 4),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - 22, center.dy + 5),
      Offset(center.dx + 20, center.dy + 5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
