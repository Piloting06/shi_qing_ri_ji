/// 统一时间格式化工具。
/// 所有时间字符串应为 ISO 8601 格式（含 Z 后缀或 UTC offset），通过 .toLocal() 转为本地时间后展示。
class TimeUtils {
  /// 解析服务端时间：SQLite `datetime('now')` 产出的裸串（如 `2026-11-03 11:20:00`）
  /// 实为 UTC 却不带时区标记，直接 tryParse 会被当成本地时间（差 8 小时）。
  /// 无时区标记的一律按 UTC 解析，再转本地。
  static DateTime? parseServer(Object? raw) {
    if (raw == null) return null;
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(' ', 'T');
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
    if (!hasZone && s.contains('T')) s = '${s}Z';
    return DateTime.tryParse(s)?.toLocal();
  }

  /// 服务端时间 → 本地 HH:mm
  static String hm(Object? raw) {
    final t = parseServer(raw);
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 相对时间：刚刚 / X分钟前 / X小时前 / 昨天 HH:MM / M月D日 HH:MM
  static String relative(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '刚刚';
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(targetDay).inDays;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (diffDays == 0) return '$hh:$mm';
    if (diffDays == 1) return '昨天 $hh:$mm';
    return '${local.month}月${local.day}日 $hh:$mm';
  }

  /// 绝对时间：2026年5月26日 周二 14:30
  static String absolute(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final wd = weekdays[local.weekday - 1];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}年${local.month}月${local.day}日 $wd $hh:$mm';
  }

  /// 短格式绝对时间：5月26日 周二 · 14:30（卡片专用）
  static String short(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final wd = weekdays[local.weekday - 1];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month}月${local.day}日 $wd · $hh:$mm';
  }
}
