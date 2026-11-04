import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../xq/xq_paper.dart';
import 'card_kit.dart';
import 'card_painting.dart';
import 'mood_card_data.dart';

/// 实寄封：一只寄出去的老式信封。左上六个红邮编格填当天日期，右上一枚当天天色的小邮票，
/// 邮戳压着邮票盖城市和日期；中间红框里写当天的话，右下落「寄自」。
class EnvelopeCardTemplate {
  EnvelopeCardTemplate._();

  static Widget build(MoodCardData d) {
    final date = DateTime.tryParse(d.rawDate) ?? DateTime.now();
    final code = '${date.year % 100}'.padLeft(2, '0') +
        '${date.month}'.padLeft(2, '0') +
        '${date.day}'.padLeft(2, '0');
    final city = (d.cityName ?? '').split('，').first.trim();
    final from = [if (city.isNotEmpty) city, if (d.username.trim().isNotEmpty) d.username.trim()].join(' · ');
    final body = d.bodyText.trim().isEmpty ? '今天没写字。' : d.bodyText.trim();
    final mark = watermarkTextFor(d.watermark);

    return Container(
      height: d.height,
      decoration: BoxDecoration(
        color: CardStock.envelope,
        image: XqPaper.grain(const Color(0xFF4A3B26), strength: 0.6),
        borderRadius: BorderRadius.circular(d.square ? 0 : 2),
        border: Border.all(color: const Color(0xFFD3CABA), width: 0.6),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), offset: const Offset(0, 1), blurRadius: 1)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 58,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final ch in code.characters) ...[
                      Container(
                        width: 17,
                        height: 19,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border.all(color: CardStock.postRed, width: 1)),
                        child: Text(ch, style: kaiStyle(12.5, CardStock.ink, height: 1)),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
                Positioned(right: 0, top: 0, child: _Stamp(d)),
                Positioned(right: 30, top: 24, child: _Postmark(city: city.isEmpty ? '拾晴' : city, date: date)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: CardStock.postRed.withAlpha(200), width: 1.1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                body,
                maxLines: d.height > 300 ? 8 : 3,
                overflow: TextOverflow.ellipsis,
                style: kaiStyle(15 * d.bodyScale, CardStock.ink, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (mark.isNotEmpty) Text(mark, style: TextStyle(fontSize: 9.5, color: CardStock.inkFaint, letterSpacing: 1)),
              const Spacer(),
              XqPigmentDab(color: moodColor(d), size: 15, seed: d.moodScore + 6),
              const SizedBox(width: 4),
              Text(d.moodLabel, style: displayStyle(12, CardStock.inkSoft)),
              const SizedBox(width: 10),
              Text(from.isEmpty ? '寄自今天' : '寄自 $from', style: kaiStyle(12.5, CardStock.inkSoft, height: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 邮票：齿孔边 + 当天天色小画 + 「拾晴」
class _Stamp extends StatelessWidget {
  const _Stamp(this.d);
  final MoodCardData d;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PerfPainter(),
      child: Container(
        width: 46,
        height: 56,
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: CardStock.inkFaint.withAlpha(90), width: 0.5)),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(child: CardPainting(condition: cardSky(d), paper: CardStock.envelope, motif: false, seed: 3)),
              ),
              Positioned(
                left: 2,
                top: 2,
                child: Text('拾晴', style: displayStyle(7.5, CardStock.ink, height: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = const Color(0xFFFBF8F1));
    // 齿孔：沿边一圈小半圆缺口（用信封底色画回去）
    final hole = Paint()..color = CardStock.envelope;
    const step = 5.0;
    for (var x = step / 2; x < size.width; x += step) {
      canvas.drawCircle(Offset(x, 0), 1.5, hole);
      canvas.drawCircle(Offset(x, size.height), 1.5, hole);
    }
    for (var y = step / 2; y < size.height; y += step) {
      canvas.drawCircle(Offset(0, y), 1.5, hole);
      canvas.drawCircle(Offset(size.width, y), 1.5, hole);
    }
  }

  @override
  bool shouldRepaint(_PerfPainter old) => false;
}

/// 邮戳：一圈细墨，中间城市与日期，左边拖三道波纹
class _Postmark extends StatelessWidget {
  const _Postmark({required this.city, required this.date});
  final String city;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = CardStock.ink.withAlpha(120);
    return Transform.rotate(
      angle: -0.18,
      child: SizedBox(
        width: 84,
        height: 40,
        child: CustomPaint(
          painter: _PostmarkPainter(c),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(city.characters.take(3).join(), style: displayStyle(8.5, c, height: 1.1)),
                  Text(
                    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 5.5, color: c, height: 1.3, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostmarkPainter extends CustomPainter {
  _PostmarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final c = Offset(size.width - 20, size.height / 2);
    canvas.drawCircle(c, 19, p);
    canvas.drawCircle(c, 15.5, p..strokeWidth = 0.5);
    for (var i = -1; i <= 1; i++) {
      final path = Path();
      final y = size.height / 2 + i * 7;
      path.moveTo(0, y);
      for (var x = 0.0; x <= size.width - 42; x += 1) {
        path.lineTo(x, y + math.sin(x / 4) * 1.6);
      }
      canvas.drawPath(path, p..strokeWidth = 0.7);
    }
  }

  @override
  bool shouldRepaint(_PostmarkPainter old) => old.color != color;
}
