import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import '../xq/xq_paper.dart';
import '../../constants/mood.dart';
import 'mood_card_data.dart';

/// 极简：大留白 + 一句话 + 极小日期，性冷淡手账风
class MinimalCardTemplate {
  MinimalCardTemplate._();

  static const _paper = Color(0xFFFEFDFB);
  static const _ink = Color(0xFF2B2A27);

  static Widget build(MoodCardData data) {
    final br = data.square ? 0.0 : 16.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(br),
        border: Border.all(color: _ink.withAlpha(22), width: 0.5),
        boxShadow: XqDecorations.shadowStrong(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: SizedBox(
          height: data.height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data.dateText,
                      style: TextStyle(
                        color: _ink.withAlpha(110),
                        fontSize: 8.5,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    XqPigmentDab(
                      color: Color(moodColors[data.moodScore] ?? 0xFF7A7871),
                      size: 14,
                      seed: data.moodScore,
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.moodLabel,
                        style: TextStyle(
                          color: _ink.withAlpha(90),
                          fontSize: 10,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 26,
                        child: Container(height: 0.6, color: _ink.withAlpha(60)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data.bodyText.isNotEmpty ? data.bodyText : ' ',
                        textAlign: TextAlign.center,
                        style: XqTypography.handwrittenBody.copyWith(
                          color: _ink,
                          fontSize: 15 * data.bodyScale,
                          height: 1.6,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      watermarkTextFor(data.watermark),
                      style: TextStyle(
                        color: _ink.withAlpha(80),
                        fontSize: 7.5,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    if (data.weatherText != null &&
                        data.weatherText!.isNotEmpty)
                      Text(
                        data.weatherText!,
                        style: TextStyle(
                          color: _ink.withAlpha(80),
                          fontSize: 8,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
