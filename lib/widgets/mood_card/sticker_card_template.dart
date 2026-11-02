import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/mood.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import 'mood_card_data.dart';

/// 手账贴纸：和纸胶带 + 贴纸 emoji + 涂鸦画笔，纸面拼贴感
class StickerCardTemplate {
  StickerCardTemplate._();

  static const _paper = Color(0xFFFDF8F0);
  static const _ink = Color(0xFF423425);

  // 和纸胶带色（随心情轮换）
  static const _tapeColors = [
    Color(0xFFE8B4B8), // 樱粉
    Color(0xFFA8C6B5), // 抹茶
    Color(0xFFA5B8D0), // 雾蓝
    Color(0xFFE5C48E), // 奶黄
  ];

  static Widget build(MoodCardData data) {
    final br = data.square ? 0.0 : 20.0;
    final tape = _tapeColors[data.moodScore % _tapeColors.length];
    final moodColor = Color(moodColors[data.moodScore] ?? 0xFF423425);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(br),
        border: Border.all(color: _ink.withAlpha(28), width: 0.5),
        boxShadow: XqDecorations.shadowStrong(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: Stack(
          children: [
            // 涂鸦底纹
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DoodlePainter(color: moodColor, seed: data.moodScore),
                ),
              ),
            ),
            // 和纸胶带两条
            Positioned(
              left: -8,
              top: 10,
              child: Transform.rotate(
                angle: -0.22,
                child: _WashiTape(color: tape),
              ),
            ),
            Positioned(
              right: -8,
              top: 4,
              child: Transform.rotate(
                angle: 0.14,
                child: _WashiTape(color: moodColor.withAlpha(120)),
              ),
            ),
            SizedBox(
              height: data.height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data.dateText,
                          style: TextStyle(
                            color: _ink.withAlpha(140),
                            fontSize: 10.5,
                          ),
                        ),
                        const Spacer(),
                        // 贴纸两枚
                        const Text('☁️', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          data.moodEmoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 2),
                        const Text('⭐', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tape.withAlpha(90),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${data.moodLabel}的一天',
                        style: XqTypography.handwrittenBody.copyWith(
                          color: _ink,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        data.bodyText.isNotEmpty ? data.bodyText : '写点什么吧',
                        style: XqTypography.handwrittenBody.copyWith(
                          color: data.bodyText.isNotEmpty
                              ? _ink
                              : _ink.withAlpha(60),
                          fontSize: (data.bodyText.isNotEmpty ? 14.0 : 13.5) * data.bodyScale,
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        if (data.tags.isNotEmpty)
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              children: data.tags.take(2).map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: moodColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      color: _ink.withAlpha(180),
                                      fontSize: 8.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (data.tags.isEmpty) const Spacer(),
                        Text(
                          watermarkTextFor(data.watermark),
                          style: TextStyle(
                            color: _ink.withAlpha(100),
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
                              color: _ink.withAlpha(80),
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
          ],
        ),
      ),
    );
  }
}

/// 和纸胶带条（半透明+锯齿两端）
class _WashiTape extends StatelessWidget {
  final Color color;
  const _WashiTape({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 22,
      decoration: BoxDecoration(
        color: color.withAlpha(130),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '❋ ❋ ❋ ❋ ❋ ❋',
        style: TextStyle(
          color: Colors.white.withAlpha(150),
          fontSize: 8,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

/// 涂鸦底纹：星星/爱心/圆点散布
class _DoodlePainter extends CustomPainter {
  final Color color;
  final int seed;
  _DoodlePainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed + 5);
    final dot = Paint()..color = color.withAlpha(26);
    for (int i = 0; i < 16; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final kind = rng.nextInt(3);
      final r = rng.nextDouble() * 2.5 + 1;
      switch (kind) {
        case 0: // 星星（四芒）
          final star = Paint()
            ..color = color.withAlpha(34)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8;
          canvas.drawLine(Offset(x - r * 2, y), Offset(x + r * 2, y), star);
          canvas.drawLine(Offset(x, y - r * 2), Offset(x, y + r * 2), star);
        case 1: // 爱心（两圆一三角近似）
          canvas.drawCircle(Offset(x - r * 0.6, y), r * 0.8, dot);
          canvas.drawCircle(Offset(x + r * 0.6, y), r * 0.8, dot);
        default:
          canvas.drawCircle(Offset(x, y), r, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) =>
      old.color != color || old.seed != seed;
}
