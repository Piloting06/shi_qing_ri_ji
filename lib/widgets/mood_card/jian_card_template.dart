import 'package:flutter/material.dart';
import '../../constants/mood.dart';
import '../../theme/xq_palette.dart';
import '../../theme/xq_paper_textures.dart';
import '../weather_sky.dart' show chineseNumber;
import '../xq/xq_kit.dart';
import '../xq/xq_paper.dart';
import 'mood_card_data.dart';

/// 笺：分享出去的那张就是一张信笺。纸色跟 App 的六张纸一致；
/// 双线笺框、朱丝栏、楷体正文、右上一枝寒枝；地脚一抹心情颜料 + 心情字，右下钤日期白文印。
class JianCardTemplate {
  JianCardTemplate._();

  static Widget build(MoodCardData data, XqPalette p) {
    final day = DateTime.tryParse(data.rawDate)?.day;
    final sealText = day == null ? '拾晴' : '${chineseNumber(day)}日';
    final weather = [
      if ((data.weatherText ?? '').isNotEmpty) data.weatherText!,
      if ((data.cityName ?? '').isNotEmpty) data.cityName!,
      if ((data.temperature ?? '').isNotEmpty) data.temperature!,
    ].join(' · ');
    final mark = watermarkTextFor(data.watermark);
    final footer = [
      if (data.username.trim().isNotEmpty) data.username.trim(),
      mark,
    ].join('  ');
    final lineGap = 26.0 * data.bodyScale;
    final fontSize = 15.0 * data.bodyScale;

    return Container(
      height: data.height,
      decoration: BoxDecoration(
        color: p.card,
        image: XqPaper.grain(p.fiber, strength: p.dark ? 0.6 : 0.8),
        borderRadius: BorderRadius.circular(data.square ? 0 : 3),
        border: Border.all(color: p.frame, width: 0.6),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(p.dark ? 60 : 22), offset: const Offset(0, 1), blurRadius: 1),
        ],
      ),
      padding: const EdgeInsets.all(7),
      // 双线笺框：外框在容器上，内框再缩一圈
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: p.border, width: 0.6)),
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 6,
              child: Image.asset(
                'assets/motifs/branch.png',
                width: 64,
                color: p.ink.withAlpha(p.dark ? 40 : 32),
                colorBlendMode: BlendMode.srcIn,
                excludeFromSemantics: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    data.dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Display', fontSize: 13, color: p.textPrimary, letterSpacing: 0.5),
                  ),
                  if (weather.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      weather,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: p.textTertiary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LinedPaperPainter(
                              lineColor: p.seal.withAlpha(p.dark ? 70 : 48),
                              lineSpacing: lineGap,
                              showMarginLine: false,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: lineGap - fontSize * 1.38),
                          child: Text(
                            data.bodyText.trim().isEmpty ? '今天没写字。' : data.bodyText.trim(),
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: fontSize,
                              height: lineGap / fontSize,
                              color: data.bodyText.trim().isEmpty ? p.textTertiary : p.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      XqPigmentDab(color: Color(moodColors[data.moodScore] ?? 0xFF7A7871), size: 18, seed: data.moodScore + 3),
                      const SizedBox(width: 6),
                      Text(
                        data.moodLabel,
                        style: TextStyle(fontFamily: 'Display', fontSize: 13, height: 1.1, color: p.textSecondary),
                        strutStyle: const StrutStyle(fontSize: 13, height: 1.1, forceStrutHeight: true),
                      ),
                      if (data.tags.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            data.tags.take(2).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: p.textTertiary),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(footer, style: TextStyle(fontSize: 10, color: p.textTertiary, letterSpacing: 1)),
                      const SizedBox(width: 8),
                      XqSeal(char: sealText, color: p.seal, size: 26, style: XqSealStyle.bai),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
