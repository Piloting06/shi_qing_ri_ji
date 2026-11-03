import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import '../../utils/solar_term_utils.dart';
import 'mood_card_data.dart';

/// 节气限定：按当前节气换季配色 + 季节场景画笔 + 节气大字印章（节日当天显示节日名）
class SeasonalCardTemplate {
  SeasonalCardTemplate._();

  static ({Color bg, Color accent, Color text}) paletteFor(String season) =>
      switch (season) {
        'summer' => (
            bg: const Color(0xFFEAF3F3),
            accent: const Color(0xFF3F7D8C),
            text: const Color(0xFF1D3A40)
          ),
        'autumn' => (
            bg: const Color(0xFFF8F1E2),
            accent: const Color(0xFFB27B2E),
            text: const Color(0xFF45300F)
          ),
        'winter' => (
            bg: const Color(0xFFEEF1F5),
            accent: const Color(0xFF6B80A0),
            text: const Color(0xFF26303E)
          ),
        _ => (
            bg: const Color(0xFFF0F5E9),
            accent: const Color(0xFF6B9A4B),
            text: const Color(0xFF2B3D1E)
          ),
      };

  static Widget build(MoodCardData data) {
    final d = DateTime.tryParse(data.rawDate) ?? DateTime.now();
    final festival = festivalOf(d);
    final term = currentSolarTerm(d);
    final season = seasonOfTerm(term);
    final p = paletteFor(season);
    final badge = festival ?? term;
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data.dateText,
                          style: TextStyle(
                            color: p.text.withAlpha(130),
                            fontSize: 10.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '节气限定',
                          style: TextStyle(
                            color: p.accent.withAlpha(140),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // 节气大字（两字竖排感 → 直接横排大号）
                        Text(
                          badge,
                          style: XqTypography.handwrittenBody.copyWith(
                            color: p.accent,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data.moodEmoji} ${data.moodLabel} · ${data.moodEn}',
                                style: TextStyle(
                                  color: p.text.withAlpha(200),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _seasonGreeting(season),
                                style: TextStyle(
                                  color: p.text.withAlpha(130),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          data.bodyText.isNotEmpty ? data.bodyText : '写点什么吧',
                          style: XqTypography.handwrittenBody.copyWith(
                            color: data.bodyText.isNotEmpty
                                ? p.text
                                : p.text.withAlpha(60),
                            fontSize: (data.bodyText.isNotEmpty ? 14.0 : 13.5) * data.bodyScale,
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
                  painter: _SeasonPainter(
                    season: season,
                    accent: p.accent,
                    seed: badge.hashCode,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _seasonGreeting(String season) => switch (season) {
        'summer' => '夏天',
        'autumn' => '秋天',
        'winter' => '冬天',
        _ => '春天',
      };
}

/// 季节场景画笔：春=枝头花点 夏=水波涟漪 秋=飘落叶 冬=雪点枯枝
class _SeasonPainter extends CustomPainter {
  final String season;
  final Color accent;
  final int seed;
  _SeasonPainter({
    required this.season,
    required this.accent,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    switch (season) {
      case 'autumn':
        // 飘落的叶（小椭圆，随机旋转）
        final leaf = Paint()..color = accent.withAlpha(60);
        for (int i = 0; i < 9; i++) {
          final x = rng.nextDouble() * size.width;
          final y = rng.nextDouble() * size.height;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(rng.nextDouble() * math.pi);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 7, height: 3.5),
            leaf,
          );
          canvas.restore();
        }
      case 'winter':
        // 雪点
        final dot = Paint()..color = accent.withAlpha(55);
        for (int i = 0; i < 30; i++) {
          canvas.drawCircle(
            Offset(rng.nextDouble() * size.width,
                rng.nextDouble() * size.height),
            rng.nextDouble() * 1.6 + 0.5,
            dot,
          );
        }
      case 'summer':
        // 水波涟漪（右上角几组弧）
        final wave = Paint()
          ..color = accent.withAlpha(40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        for (int i = 0; i < 3; i++) {
          final y = 26.0 + i * 13;
          canvas.drawArc(
            Rect.fromLTWH(size.width - 74, y, 52, 10),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            wave,
          );
        }
      default:
        // 春：枝头花点（右上角一根枝 + 粉绿花点）
        final branch = Paint()
          ..color = accent.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        final stem = Path()
          ..moveTo(size.width - 16, 18)
          ..quadraticBezierTo(size.width - 48, 30, size.width - 74, 22);
        canvas.drawPath(stem, branch);
        final bloom = Paint();
        for (int i = 0; i < 7; i++) {
          bloom.color = i.isEven
              ? accent.withAlpha(90)
              : Colors.white.withAlpha(150);
          canvas.drawCircle(
            Offset(size.width - 30 - rng.nextDouble() * 42,
                18 + rng.nextDouble() * 14),
            rng.nextDouble() * 2 + 1.2,
            bloom,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonPainter old) =>
      old.season != season || old.accent != accent || old.seed != seed;
}
