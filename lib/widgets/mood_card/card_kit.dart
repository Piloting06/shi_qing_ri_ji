import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../constants/mood.dart';
import '../../theme/xq_typography.dart';
import '../weather_sky.dart';
import 'mood_card_data.dart';

/// 卡片共用的小零件：竖排文字、卡面材料色、天气 → 天色。

/// 竖排：自右向左成列；按可用高度自动分列，放不下的收成「︙」。
/// 标点挪到字格右上，「」换成竖排引号。换行另起一列。
class VText extends StatelessWidget {
  const VText(
    this.text, {
    super.key,
    required this.style,
    this.columnGap = 6,
    this.lineHeight = 1.18,
  });

  final String text;
  final TextStyle style;
  final double columnGap;
  final double lineHeight;

  static const _punct = '，。、；：！？';
  static const _vertical = {'「': '﹁', '」': '﹂', '『': '﹃', '』': '﹄', '（': '︵', '）': '︶', '…': '︙', '—': '︱'};

  @override
  Widget build(BuildContext context) {
    final fs = style.fontSize ?? 14;
    final cellH = fs * lineHeight;
    final cellW = fs * 1.12;
    return LayoutBuilder(builder: (context, c) {
      // 留半格给挂在列尾的标点
      final perCol = math.max(1, ((c.maxHeight - cellH * 0.55) / cellH).floor());
      final maxCols = math.max(1, ((c.maxWidth + columnGap) / (cellW + columnGap)).floor());
      final cols = <List<String>>[];
      var cur = <String>[];
      for (final ch in text.trim().characters) {
        if (ch == '\n') {
          if (cur.isNotEmpty) cols.add(cur);
          cur = [];
          continue;
        }
        final v = _vertical[ch] ?? ch;
        // 标点不起列：本该落到新列开头的标点，挂在上一列末尾（只挂一个，连续句读不再往上挂，免得列高溢出）
        if (cur.isEmpty && cols.isNotEmpty && _punct.contains(v) && !_punct.contains(cols.last.last)) {
          cols.last.add(v);
          continue;
        }
        cur.add(v);
        if (cur.length == perCol) {
          cols.add(cur);
          cur = [];
        }
      }
      if (cur.isNotEmpty) cols.add(cur);
      if (cols.length > maxCols) {
        cols.removeRange(maxCols, cols.length);
        final last = cols.last;
        last[last.length - 1] = '︙';
      }
      Widget cell(String ch) {
        final p = _punct.contains(ch);
        if (p) {
          // 横排字体里句读在字格左下；竖排要在右上：把字形往右上挪，不裁切
          return SizedBox(
            width: cellW,
            height: cellH * 0.55,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -fs * 0.02,
                  top: -fs * 0.48,
                  child: Text(ch, softWrap: false, overflow: TextOverflow.visible, style: style.copyWith(height: 1)),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          width: cellW,
          height: cellH,
          child: Center(child: Text(ch, softWrap: false, overflow: TextOverflow.visible, style: style.copyWith(height: 1))),
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, col) in cols.reversed.indexed) ...[
            if (i > 0) SizedBox(width: columnGap),
            Column(mainAxisSize: MainAxisSize.min, children: [for (final ch in col) cell(ch)]),
          ],
        ],
      );
    });
  }
}

/// 卡面材料
class CardStock {
  CardStock._();
  static const silk = Color(0xFFE8DDC6); // 绢本（册页）
  static const silkEdge = Color(0xFF9C8566); // 册页的绫边
  static const goldPaper = Color(0xFFF0E5C9); // 洒金笺（扇面）
  static const gold = Color(0xFFC9A55A);
  static const envelope = Color(0xFFF3EEE2); // 信封
  static const postRed = Color(0xFFB8402E); // 信封红框、邮编格
  static const ink = Color(0xFF26231E);
  static const inkSoft = Color(0xFF5A544A);
  static const inkFaint = Color(0xFF857D70);
  static const seal = Color(0xFFAE3624);
}

/// 楷体（内容层）
TextStyle kaiStyle(double size, Color color, {double height = 1.5}) => TextStyle(
      fontFamily: XqTypography.content,
      fontFamilyFallback: XqTypography.contentFallback,
      fontSize: size,
      color: color,
      height: height,
    );

/// 展示体（朱雀仿宋）
TextStyle displayStyle(double size, Color color, {double height = 1.2, double spacing = 0}) => TextStyle(
      fontFamily: 'Display',
      fontFamilyFallback: const ['SerifSC'],
      fontSize: size,
      color: color,
      height: height,
      letterSpacing: spacing,
    );

/// 卡上的天气 → 天况；没有天气时按晴
SkyCondition cardSky(MoodCardData d) => skyConditionFor(null, d.weatherText ?? '晴');

Color moodColor(MoodCardData d) => Color(moodColors[d.moodScore] ?? 0xFF7A7871);

/// 卡片日期 → 「十一月五日」
String hanziMonthDay(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return '';
  return '${chineseNumber(d.month)}月${chineseNumber(d.day)}日';
}

/// 「二〇二六」
String hanziYear(int y) {
  const digits = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  return y.toString().split('').map((c) => digits[int.parse(c)]).join();
}

/// 日期印：「五日」「十五日」「三十一日」
String daySealText(String raw) {
  final d = DateTime.tryParse(raw);
  return d == null ? '拾晴' : '${chineseNumber(d.day)}日';
}

/// 洒金：在 rect 里撒一层金箔碎点（种子固定，同一张卡每次一样）
void paintGoldFlecks(Canvas canvas, Rect rect, {int seed = 3, int count = 90, Color color = CardStock.gold}) {
  final rnd = math.Random(seed);
  final paint = Paint()..color = color.withAlpha(150);
  for (var i = 0; i < count; i++) {
    final c = Offset(rect.left + rnd.nextDouble() * rect.width, rect.top + rnd.nextDouble() * rect.height);
    final r = 0.5 + rnd.nextDouble() * 1.6;
    final path = Path();
    final n = 4 + rnd.nextInt(3);
    for (var k = 0; k < n; k++) {
      final a = k / n * math.pi * 2 + rnd.nextDouble();
      final rr = r * (0.6 + rnd.nextDouble() * 0.8);
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint..color = color.withAlpha(90 + rnd.nextInt(110)));
  }
}
