import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/utils/time_utils.dart';

void main() {
  test('服务端裸时间按 UTC 解析（SQLite datetime 无时区标记）', () {
    final t = TimeUtils.parseServer('2026-11-03 11:20:00')!;
    expect(t.toUtc(), DateTime.utc(2026, 11, 3, 11, 20));
  });

  test('带 Z / 偏移的时间保持原义', () {
    expect(TimeUtils.parseServer('2026-11-03T11:20:00Z')!.toUtc(),
        DateTime.utc(2026, 11, 3, 11, 20));
    expect(TimeUtils.parseServer('2026-11-03T19:20:00+08:00')!.toUtc(),
        DateTime.utc(2026, 11, 3, 11, 20));
  });

  test('hm 输出本地时分，空值与非法值返回空串', () {
    final local = DateTime.utc(2026, 11, 3, 11, 20).toLocal();
    final expected =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    expect(TimeUtils.hm('2026-11-03 11:20:00'), expected);
    expect(TimeUtils.hm(null), '');
    expect(TimeUtils.hm('不是时间'), '');
  });
}
