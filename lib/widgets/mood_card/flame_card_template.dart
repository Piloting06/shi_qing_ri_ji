import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../xq/xq_icons.dart';
import 'mood_card_data.dart';

/// 火焰卡：连续记录天数 + 最近7天打卡点（社交货币型卡片）
class FlameCardTemplate {
  FlameCardTemplate._();

  static const _ember = Color(0xFFFF7A3D);
  static const _emberDeep = Color(0xFFB23A1B);

  static Widget build(MoodCardData data) {
    final br = data.square ? 0.0 : 20.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(br),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF33190A), Color(0xFF1D0E06)],
        ),
        border: Border.all(color: _ember.withAlpha(40), width: 0.6),
        boxShadow: XqDecorations.shadowStrong(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: Stack(
          children: [
            // 底部余烬光晕
            Positioned(
              left: -40,
              bottom: -60,
              child: Container(
                width: 180,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _ember.withAlpha(46),
                      _emberDeep.withAlpha(14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: data.height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          data.dateText,
                          style: TextStyle(
                            color: Colors.white.withAlpha(120),
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '连续记录',
                          style: TextStyle(
                            color: _ember.withAlpha(150),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const XqIcon(XqIcons.flame, size: 36, color: _ember),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFFFFC866),
                                      _ember,
                                      _emberDeep,
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    '${data.streakDays}',
                                    style: const TextStyle(
                                      fontSize: 52,
                                      height: 1.0,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '天',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(190),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.streakDays > 0
                                  ? '连续记录'
                                  : '从今天开始记',
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 最近7天打卡条
                    if (data.week.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: data.week.reversed.map((day) {
                          final recorded = day.color != null;
                          return Column(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: recorded
                                      ? Color(day.color ?? 0xFFFF7A3D)
                                          .withAlpha(210)
                                      : Colors.white.withAlpha(16),
                                  border: Border.all(
                                    color: recorded
                                        ? Colors.transparent
                                        : Colors.white.withAlpha(45),
                                    width: 0.8,
                                  ),
                                ),
                                child: recorded
                                    ? null
                                    : Text(
                                        day.label,
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(80),
                                          fontSize: 8,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                day.isToday ? '今天' : day.label,
                                style: TextStyle(
                                  color: day.isToday
                                      ? _ember.withAlpha(200)
                                      : Colors.white.withAlpha(80),
                                  fontSize: 7.5,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          watermarkTextFor(data.watermark),
                          style: TextStyle(
                            color: Colors.white.withAlpha(90),
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
                              color: Colors.white.withAlpha(70),
                              fontSize: 8,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (data.tags.isNotEmpty)
                          Text(
                            data.tags.take(2).join(' · '),
                            style: TextStyle(
                              color: Colors.white.withAlpha(90),
                              fontSize: 8.5,
                            ),
                          ),
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
