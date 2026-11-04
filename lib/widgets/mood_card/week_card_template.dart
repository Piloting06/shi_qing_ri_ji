import 'package:flutter/material.dart';
import '../../theme/xq_palette.dart';
import '../weather_sky.dart' show chineseCount;
import '../xq/xq_kit.dart';
import '../xq/xq_paper.dart';
import 'card_kit.dart';
import 'mood_card_data.dart';

/// 七日：一张笺上七栏，自左向右是这七天；记过的那天一抹颜料、竖写心情字，没记的留一个空圈。
class WeekCardTemplate {
  WeekCardTemplate._();

  static Widget build(MoodCardData d) {
    const p = XqPalette.sujian;
    final days = d.week.reversed.toList(); // week 是今天在前
    final recorded = days.where((x) => x.color != null).toList();
    final counts = <String, int>{};
    for (final x in recorded) {
      if (x.mood != null) counts[x.mood!] = (counts[x.mood!] ?? 0) + 1;
    }
    String? top;
    var topN = 0;
    counts.forEach((k, v) {
      if (v > topN) {
        top = k;
        topN = v;
      }
    });
    final summary = recorded.isEmpty
        ? '这七天还没记。'
        : '七天记了${chineseCount(recorded.length)}天${top != null && topN > 1 ? '，$top最多' : ''}。';
    final mark = watermarkTextFor(d.watermark);

    return Container(
      height: d.height,
      decoration: BoxDecoration(
        color: p.card,
        image: XqPaper.grain(p.fiber, strength: 0.8),
        borderRadius: BorderRadius.circular(d.square ? 0 : 3),
        border: Border.all(color: p.frame, width: 0.6),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(22), offset: const Offset(0, 1), blurRadius: 1)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('七日', style: displayStyle(18, p.textPrimary, spacing: 2)),
              const SizedBox(width: 10),
              Text('到${hanziMonthDay(d.rawDate)}', style: TextStyle(fontSize: 11, color: p.textTertiary)),
              const Spacer(),
              XqSeal(char: daySealText(d.rawDate), color: p.seal, size: 24, style: XqSealStyle.bai),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: p.frame, width: 0.6))),
              child: Row(
                children: [
                  for (final (i, x) in days.indexed) ...[
                    if (i > 0) Container(width: 0.6, color: p.border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Text(x.label, style: displayStyle(14, x.isToday ? p.textPrimary : p.textSecondary)),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 24,
                              child: Center(
                                child: x.color != null
                                    ? XqPigmentDab(color: Color(x.color!), size: 22, seed: i + 3)
                                    : Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: p.frame, width: 0.8),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: x.mood == null
                                  ? const SizedBox.shrink()
                                  : VText(x.mood!, style: kaiStyle(12, p.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(summary, style: kaiStyle(12.5, p.textSecondary, height: 1.2)),
              const Spacer(),
              if (mark.isNotEmpty) Text(mark, style: TextStyle(fontSize: 9.5, color: p.textTertiary, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }
}
