import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import 'mood_card_data.dart';

/// 周历卡：最近7天心情一排（心情是类别不是分值，所以用日历而非曲线），
/// 底部汇总记录天数与最常出现的心情。
class WeeklyCardTemplate {
  WeeklyCardTemplate._();

  static const _paper = Color(0xFFFBF6EC);
  static const _ink = Color(0xFF33291C);
  static const _accent = Color(0xFF8A7350);

  static Widget build(MoodCardData data) {
    final br = data.square ? 0.0 : 20.0;
    final week = data.week;
    final recorded = week.where((d) => d.emoji != null && d.emoji!.isNotEmpty).length;

    // 最常出现的心情
    String? topEmoji;
    int? topColor;
    var topCount = 0;
    final counts = <String, int>{};
    final colorOf = <String, int?>{};
    for (final d in week) {
      if (d.emoji == null || d.emoji!.isEmpty) continue;
      counts[d.emoji!] = (counts[d.emoji!] ?? 0) + 1;
      colorOf[d.emoji!] = d.color;
    }
    for (final e in counts.entries) {
      if (e.value > topCount) {
        topCount = e.value;
        topEmoji = e.key;
        topColor = colorOf[e.key];
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(br),
        border: Border.all(color: _accent.withAlpha(50), width: 0.5),
        boxShadow: XqDecorations.shadowStrong(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: SizedBox(
          height: data.height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '本周心情日历',
                      style: XqTypography.handwrittenBody.copyWith(
                        color: _ink,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      data.dateText,
                      style: TextStyle(
                        color: _ink.withAlpha(120),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'MY WEEK IN MOODS',
                  style: TextStyle(
                    color: _accent.withAlpha(150),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                // 7 天一排
                if (week.isNotEmpty)
                  Row(
                    children: week.map((day) {
                      final recordedDay = day.emoji != null && day.emoji!.isNotEmpty;
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: recordedDay
                                    ? Color(day.color ?? 0xFFE0D5C0)
                                        .withAlpha(90)
                                    : _ink.withAlpha(8),
                                border: day.isToday
                                    ? Border.all(
                                        color: _accent.withAlpha(150),
                                        width: 1.2,
                                      )
                                    : Border.all(
                                        color: _ink.withAlpha(20),
                                        width: 0.6,
                                      ),
                              ),
                              child: recordedDay
                                  ? Text(
                                      day.emoji!,
                                      style: const TextStyle(fontSize: 15),
                                    )
                                  : Text(
                                      '·',
                                      style: TextStyle(
                                        color: _ink.withAlpha(70),
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              day.isToday ? '今' : day.label,
                              style: TextStyle(
                                color: day.isToday
                                    ? _accent
                                    : _ink.withAlpha(100),
                                fontSize: 9,
                                fontWeight: day.isToday
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const Spacer(),
                // 汇总行
                Container(
                  height: 1,
                  color: _ink.withAlpha(25),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '记录 $recorded/7 天',
                      style: TextStyle(
                        color: _ink.withAlpha(170),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (topEmoji != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        '最常出现 $topEmoji ×$topCount',
                        style: TextStyle(
                          color: Color(topColor ?? 0xFF8A7350),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      watermarkTextFor(data.watermark),
                      style: TextStyle(
                        color: _accent.withAlpha(120),
                        fontSize: 8.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: data.watermark == 'sqrj' ? 1.5 : 1.15,
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
