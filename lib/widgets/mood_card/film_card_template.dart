import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import 'mood_card_data.dart';

/// 胶片：黑白噪点 + 齿孔片边 + 橙色曝光日期戳
class FilmCardTemplate {
  FilmCardTemplate._();

  static const _bg = Color(0xFF151412);
  static const _cream = Color(0xFFECE6DA);
  static const _orange = Color(0xFFFF8A50);

  static Widget build(MoodCardData data) {
    final br = data.square ? 0.0 : 16.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(br),
        border: Border.all(color: Colors.white.withAlpha(16), width: 0.5),
        boxShadow: XqDecorations.shadowStrong(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _FilmGrainPainter())),
            ),
            SizedBox(
              height: data.height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  children: [
                    const _SprocketRow(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      data.dateText,
                                      style: const TextStyle(
                                        color: _orange,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'SQ·36 — FRAME ${data.moodEn}',
                                      style: TextStyle(
                                        color: _cream.withAlpha(90),
                                        fontSize: 8,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (data.weatherText != null &&
                                    data.weatherText!.isNotEmpty)
                                  Text(
                                    '${data.weatherText}${data.cityName != null ? " · ${data.cityName}" : ""}',
                                    style: TextStyle(
                                      color: _cream.withAlpha(110),
                                      fontSize: 9.5,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Text(
                                    data.bodyText.isNotEmpty
                                        ? data.bodyText
                                        : '写点什么吧',
                                    style: XqTypography.handwrittenBody.copyWith(
                                      color: data.bodyText.isNotEmpty
                                          ? _cream
                                          : _cream.withAlpha(60),
                                      fontSize:
                                          (data.bodyText.isNotEmpty
                                                  ? 14.5
                                                  : 14.0) *
                                              data.bodyScale,
                                      height: 1.4,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${data.moodEmoji} ${data.moodLabel}',
                                      style: TextStyle(
                                        color: _cream.withAlpha(150),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      watermarkTextFor(data.watermark),
                                      style: TextStyle(
                                        color: _cream.withAlpha(80),
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
                                          color: _cream.withAlpha(60),
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _SprocketRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 胶片齿孔行
class _SprocketRow extends StatelessWidget {
  const _SprocketRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 24).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(count, (i) {
              return Container(
                width: 12,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.white.withAlpha(30), width: 0.5),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(21);
    for (int i = 0; i < 260; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble();
      canvas.drawCircle(
        Offset(x, y),
        rng.nextDouble() * 0.7 + 0.15,
        Paint()..color = Colors.white.withAlpha((a * 14).toInt()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
