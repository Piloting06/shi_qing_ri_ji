import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/data/solar_term_notes.dart';
import 'package:xin_qing_ri_ji/utils/solar_term_utils.dart';

void main() {
  test('一年里每一天都能翻到当天节气的小笺，三候齐全', () {
    for (var d = DateTime(2026, 1, 1); d.year == 2026; d = d.add(const Duration(days: 1))) {
      final term = currentSolarTerm(d);
      final note = solarTermNotes[term];
      expect(note, isNotNull, reason: '$d → $term 没有小笺');
      expect(note!.hou.length, 3);
      expect(note.note, isNotEmpty);
      expect(note.line, matches(RegExp(r'[。？]$')));
    }
    expect(solarTermNotes.length, 24);
  });

  test('下一个节气', () {
    final n = nextSolarTerm(DateTime(2026, 11, 4));
    expect(n.name, '立冬');
    expect(n.date, DateTime(2026, 11, 7));
    // 节气当天，下一个是后面那个
    expect(nextSolarTerm(DateTime(2026, 11, 7)).name, '小雪');
    // 跨年
    final y = nextSolarTerm(DateTime(2026, 12, 30));
    expect(y.name, '小寒');
    expect(y.date, DateTime(2027, 1, 6));
  });
}
