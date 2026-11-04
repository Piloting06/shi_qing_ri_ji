import 'package:flutter/material.dart';
import '../xq/xq_kit.dart';
import '../xq/xq_paper.dart';
import 'card_kit.dart';
import 'card_painting.dart';
import 'mood_card_data.dart';

/// 册页：一开两页的小册。左页一幅当天天色的小画，右页竖写当天的话；中缝一道折痕，四周一圈绫边。
class AlbumLeafCardTemplate {
  AlbumLeafCardTemplate._();

  static Widget build(MoodCardData d) {
    final cond = cardSky(d);
    final day = DateTime.tryParse(d.rawDate)?.day ?? 7;
    final body = d.bodyText.trim().isEmpty ? '今天没写字。' : d.bodyText.trim();
    final mark = watermarkTextFor(d.watermark);
    return Container(
      height: d.height,
      decoration: BoxDecoration(
        color: CardStock.silkEdge,
        borderRadius: BorderRadius.circular(d.square ? 0 : 2),
      ),
      padding: const EdgeInsets.all(7),
      child: Container(
        decoration: BoxDecoration(
          color: CardStock.silk,
          image: XqPaper.grain(const Color(0xFF5A4630), strength: 0.7),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: CardStock.inkFaint.withAlpha(120), width: 0.6)),
                  child: ClipRect(child: CardPainting(condition: cond, paper: CardStock.silk, seed: day)),
                ),
              ),
            ),
            // 中缝：一道浅一道深，像对折过
            Container(width: 0.8, color: Colors.black.withAlpha(30)),
            Container(width: 0.8, color: Colors.white.withAlpha(90)),
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.topRight,
                              child: VText(body, style: kaiStyle(14 * d.bodyScale, CardStock.ink), columnGap: 5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 14,
                            child: VText(hanziMonthDay(d.rawDate), style: displayStyle(11.5, CardStock.inkSoft)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        XqPigmentDab(color: moodColor(d), size: 15, seed: d.moodScore + 2),
                        const SizedBox(width: 4),
                        Text(d.moodLabel, style: displayStyle(12, CardStock.inkSoft)),
                        const Spacer(),
                        if (mark.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(mark, style: TextStyle(fontSize: 9, color: CardStock.inkFaint, letterSpacing: 1)),
                          ),
                        XqSeal(char: daySealText(d.rawDate), color: CardStock.seal, size: 22, style: XqSealStyle.bai),
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
