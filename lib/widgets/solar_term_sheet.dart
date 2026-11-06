import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/solar_term_notes.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../utils/solar_term_utils.dart';
import 'weather_sky.dart' show chineseNumber;
import 'xq/xq_kit.dart';
import 'xq/xq_paper.dart';

/// 节气小笺：这个节气的三候（标出此刻在第几候）、一句白话、一句古诗、下一个节气。
Future<void> showSolarTermSheet(BuildContext context, DateTime now) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => SolarTermSheet(now: now),
  );
}

class SolarTermSheet extends StatelessWidget {
  const SolarTermSheet({super.key, required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    final term = currentSolarTerm(now);
    final note = solarTermNotes[term]!;
    final day = daysIntoSolarTerm(now);
    final houIndex = ((day - 1) ~/ 5).clamp(0, 2);
    final next = nextSolarTerm(now);
    const order = ['一候', '二候', '三候'];

    return DecoratedBox(
      decoration: BoxDecoration(
        image: XqPaper.grain(t.paperFiber, strength: t.isDark ? 0.6 : 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 32, height: 3, decoration: BoxDecoration(color: t.borderColor, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  XqSeal(char: term, color: t.sealColor, size: 52, style: XqSealStyle.bai),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(term, style: XqTypography.displayMedium.copyWith(color: t.textPrimary, fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          '入$term第${chineseNumber(day)}天',
                          style: TextStyle(color: t.textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // 三候：五天一候，此刻所在的那一候用墨色和一道下划线
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 42,
                        child: Text(order[i], style: TextStyle(color: t.gold, fontSize: 12.5, letterSpacing: 1)),
                      ),
                      Expanded(
                        child: Text(
                          note.hou[i],
                          style: XqTypography.headlineSmall.copyWith(
                            color: i == houIndex ? t.textPrimary : t.textSecondary,
                            fontSize: 17,
                            decoration: i == houIndex ? TextDecoration.underline : null,
                            decorationColor: t.sealColor.withAlpha(150),
                            decorationThickness: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(height: 0.6, color: t.borderColor),
              const SizedBox(height: 14),
              Text(note.note, style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.7)),
              const SizedBox(height: 16),
              Text(
                note.line,
                style: TextStyle(
                  fontFamily: XqTypography.content,
                  fontFamilyFallback: XqTypography.contentFallback,
                  color: t.textPrimary,
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${note.author}《${note.title}》', style: TextStyle(color: t.textTertiary, fontSize: 12.5)),
              ),
              const SizedBox(height: 18),
              Text(
                '下一个 · ${next.name} ${chineseNumber(next.date.month)}月${chineseNumber(next.date.day)}日',
                style: TextStyle(color: t.textTertiary, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
