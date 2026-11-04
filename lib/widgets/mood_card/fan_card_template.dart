import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../xq/xq_kit.dart';
import '../xq/xq_paper.dart';
import 'card_kit.dart';
import 'mood_card_data.dart';

/// 扇面：一把洒金折扇，字顺着扇骨一列一列写下去（自右向左），最后一列落日期与署名。
class FanCardTemplate {
  FanCardTemplate._();

  static Widget build(MoodCardData d) {
    return Container(
      height: d.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7E1D4),
        image: XqPaper.grain(const Color(0xFF4A3B26), strength: 0.7),
        borderRadius: BorderRadius.circular(d.square ? 0 : 2),
        border: Border.all(color: const Color(0xFFC6BDAA), width: 0.6),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final g = _FanGeometry.of(size);
        final square = size.height > size.width * 0.8;
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _FanPainter(d, g))),
            if (square)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _moodMark(d),
                    const SizedBox(width: 18),
                    XqSeal(char: daySealText(d.rawDate), color: CardStock.seal, size: 26, style: XqSealStyle.bai),
                  ],
                ),
              )
            else ...[
              Positioned(left: 12, bottom: 10, child: _moodMark(d)),
              Positioned(
                right: 12,
                bottom: 10,
                child: XqSeal(char: daySealText(d.rawDate), color: CardStock.seal, size: 26, style: XqSealStyle.bai),
              ),
            ],
          ],
        );
      }),
    );
  }

  static Widget _moodMark(MoodCardData d) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XqPigmentDab(color: moodColor(d), size: 16, seed: d.moodScore + 4),
          const SizedBox(width: 4),
          Text(d.moodLabel, style: displayStyle(12.5, CardStock.inkSoft)),
        ],
      );
}

class _FanGeometry {
  _FanGeometry(this.center, this.outer, this.inner, this.half);
  final Offset center;
  final double outer, inner, half; // half：半张角（弧度，自竖直向上量）

  static _FanGeometry of(Size s) {
    const half = 42 * math.pi / 180;
    final outer = math.min(s.width / (2 * math.sin(half)) - 6, s.height * 1.14);
    final cy = 8 + outer;
    final inner = math.max(outer * 0.42, cy - s.height + 14);
    return _FanGeometry(Offset(s.width / 2, cy), outer, inner, half);
  }

  Offset at(double theta, double r) => center + Offset(math.sin(theta) * r, -math.cos(theta) * r);
}

class _FanPainter extends CustomPainter {
  _FanPainter(this.d, this.g);
  final MoodCardData d;
  final _FanGeometry g;

  Path _sector(double a0, double a1, double r0, double r1) {
    final rect1 = Rect.fromCircle(center: g.center, radius: r1);
    final rect0 = Rect.fromCircle(center: g.center, radius: r0);
    return Path()
      ..arcTo(rect1, -math.pi / 2 + a0, a1 - a0, true)
      ..arcTo(rect0, -math.pi / 2 + a1, a0 - a1, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fan = _sector(-g.half, g.half, g.inner, g.outer);
    // 扇面底下一层很淡的投影
    canvas.drawPath(fan.shift(const Offset(0, 2)), Paint()..color = Colors.black.withAlpha(22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(fan, Paint()..color = CardStock.goldPaper);
    canvas.save();
    canvas.clipPath(fan);
    paintGoldFlecks(canvas, Offset.zero & size, seed: d.moodScore * 7 + 1, count: 120);
    // 折痕：相邻两折一明一暗
    const folds = 16;
    for (var i = 0; i < folds; i++) {
      final a0 = -g.half + 2 * g.half * i / folds;
      final a1 = -g.half + 2 * g.half * (i + 1) / folds;
      canvas.drawPath(
        _sector(a0, a1, g.inner, g.outer),
        Paint()..color = (i.isEven ? Colors.black : Colors.white).withAlpha(i.isEven ? 10 : 26),
      );
    }
    canvas.restore();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF8A7A5E).withAlpha(170);
    canvas.drawPath(fan, edge);

    _paintText(canvas);
  }

  void _paintText(Canvas canvas) {
    const fs = 13.5;
    const cell = fs * 1.14;
    final pad = (g.outer - g.inner) * 0.08;
    final perCol = ((g.outer - g.inner - pad * 2) / cell).floor();
    // 一列占两折：最里面那个字的弧距也比字宽，列与列不挤
    const cols = 8;
    final colAngles = [for (var i = cols - 1; i >= 0; i--) -g.half + 2 * g.half * (i + 0.5) / cols];
    // 扇面题字不点断：逗号顿号去掉，句号留一格空
    final raw = (d.bodyText.trim().isEmpty ? '今天没写字' : d.bodyText.trim()).replaceAll(RegExp(r'\s+'), '');
    final chars = <String>[];
    for (final ch in raw.characters) {
      if ('，、；：！？“”「」'.contains(ch)) continue;
      chars.add(ch == '。' ? ' ' : ch);
    }
    while (chars.isNotEmpty && chars.last == ' ') {
      chars.removeLast();
    }
    // 最左两列留给落款（日期、署名）
    const usable = cols - 2;
    final body = <List<String>>[];
    for (var i = 0; i < chars.length && body.length < usable; i += perCol) {
      final col = chars.sublist(i, math.min(i + perCol, chars.length));
      while (col.isNotEmpty && col.first == ' ') {
        col.removeAt(0);
      }
      if (col.isNotEmpty) body.add(col);
    }
    if (body.length == usable && body.fold<int>(0, (n, c) => n + c.length) < chars.where((c) => c != ' ').length) {
      body.last[body.last.length - 1] = '︙';
    }
    for (var c = 0; c < body.length; c++) {
      _column(canvas, colAngles[c], body[c], fs, cell, g.outer - pad, CardStock.ink);
    }
    // 落款：低一字起，小一号
    final signAt = body.length;
    _column(canvas, colAngles[signAt], hanziMonthDay(d.rawDate).characters.toList(), 11, 11 * 1.2, g.outer - pad - cell, CardStock.inkSoft);
    final name = d.username.trim();
    if (name.isNotEmpty && signAt + 1 < cols) {
      _column(canvas, colAngles[signAt + 1], name.characters.take(4).toList(), 11, 11 * 1.2, g.outer - pad - cell, CardStock.inkSoft);
    }
  }

  void _column(Canvas canvas, double theta, List<String> chars, double fs, double cell, double startR, Color color) {
    for (var k = 0; k < chars.length; k++) {
      final ch = chars[k];
      if (ch.trim().isEmpty) continue;
      final r = startR - (k + 0.5) * cell;
      final p = g.at(theta, r);
      final tp = TextPainter(
        text: TextSpan(text: ch, style: kaiStyle(fs, color, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(theta);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FanPainter old) => true;
}
