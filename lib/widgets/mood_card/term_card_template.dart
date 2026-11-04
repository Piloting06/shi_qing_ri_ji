import 'package:flutter/material.dart';
import '../../data/solar_term_notes.dart';
import '../../theme/xq_palette.dart';
import '../../theme/xq_paper_textures.dart';
import '../../utils/solar_term_utils.dart';
import '../weather_sky.dart' show chineseNumber;
import '../xq/xq_kit.dart';
import '../xq/xq_paper.dart';
import 'card_kit.dart';
import 'mood_card_data.dart';

/// 节气：左边一方白文节气印，下注「入立冬第三天」；右边这几天的那一候和节气诗，下面朱丝栏写当天的话。
class TermCardTemplate {
  TermCardTemplate._();

  static Widget build(MoodCardData d) {
    const p = XqPalette.sujian;
    final date = DateTime.tryParse(d.rawDate) ?? DateTime.now();
    final term = currentSolarTerm(date);
    final note = solarTermNotes[term]!;
    final day = daysIntoSolarTerm(date);
    final hou = note.hou[((day - 1) ~/ 5).clamp(0, 2)];
    const houName = ['一候', '二候', '三候'];
    final body = d.bodyText.trim().isEmpty ? '今天没写字。' : d.bodyText.trim();
    final lineGap = 24.0 * d.bodyScale;
    final fs = 14.0 * d.bodyScale;
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
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 66,
            child: Column(
              children: [
                XqSeal(char: term, color: p.seal, size: 58, style: XqSealStyle.bai),
                const SizedBox(height: 8),
                Text('入$term', style: displayStyle(11.5, p.textSecondary)),
                Text('第${chineseNumber(day)}天', style: displayStyle(11.5, p.textSecondary)),
                const Spacer(),
                Text(hanziMonthDay(d.rawDate), style: TextStyle(fontSize: 9.5, color: p.textTertiary)),
              ],
            ),
          ),
          Container(width: 0.6, margin: const EdgeInsets.symmetric(horizontal: 12), color: p.border),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${houName[((day - 1) ~/ 5).clamp(0, 2)]}　', style: TextStyle(fontSize: 10.5, color: p.gold)),
                    TextSpan(text: hou, style: displayStyle(14, p.textPrimary)),
                  ]),
                  maxLines: 1,
                ),
                const SizedBox(height: 3),
                Text(
                  '${note.line}　${note.author}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kaiStyle(11, p.textTertiary, height: 1.3),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: LinedPaperPainter(lineColor: p.seal.withAlpha(48), lineSpacing: lineGap, showMarginLine: false),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: lineGap - fs * 1.38),
                        child: Text(body, overflow: TextOverflow.fade, style: kaiStyle(fs, p.textPrimary, height: lineGap / fs)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    XqPigmentDab(color: moodColor(d), size: 15, seed: d.moodScore + 8),
                    const SizedBox(width: 4),
                    Text(d.moodLabel, style: displayStyle(12, p.textSecondary)),
                    const Spacer(),
                    Text(
                      [if (d.username.trim().isNotEmpty) d.username.trim(), mark].where((e) => e.isNotEmpty).join('  '),
                      style: TextStyle(fontSize: 9.5, color: p.textTertiary, letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
