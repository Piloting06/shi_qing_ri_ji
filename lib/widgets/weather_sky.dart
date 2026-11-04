import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'xq/xq_paper.dart';

/// 天色：首页主视觉。随真实天气（6 种）与时辰（4 段）变化的一张「笺头画」。
/// P9 起画法从「渐变 + 剪影」改为木版套色：刷痕、错版、断续勾线、版面侵蚀、纸纹透出，点景取自《芥子园画传》。
/// 纯逻辑（天况/时辰/色板/文案/中文数字）与画笔分开，逻辑见 test/weather_sky_test.dart。

enum SkyCondition { clear, cloudy, overcast, fog, rain, snow }

enum SkyTime { dawn, day, dusk, night }

/// 天气码（WMO，服务端已映射）+ 文案 → 天况。码优先，文案兜底。
SkyCondition skyConditionFor(int? code, [String? text]) {
  if (code != null) {
    if (code == 0 || code == 1) return SkyCondition.clear;
    if (code == 2) return SkyCondition.cloudy;
    if (code == 3) return SkyCondition.overcast;
    if (code == 45 || code == 48) return SkyCondition.fog;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return SkyCondition.snow;
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95) {
      return SkyCondition.rain;
    }
  }
  final t = text ?? '';
  if (t.contains('雪')) return SkyCondition.snow;
  if (t.contains('雨')) return SkyCondition.rain;
  if (t.contains('雾') || t.contains('霾')) return SkyCondition.fog;
  if (t.contains('阴')) return SkyCondition.overcast;
  if (t.contains('云')) return SkyCondition.cloudy;
  return SkyCondition.clear;
}

/// 时辰：日出/日落前后各一小时为晨/暮；无数据时按 6:00 / 18:00。
SkyTime skyTimeFor(DateTime now, {String? sunrise, String? sunset}) {
  int minutes(String? hm, int fallback) {
    final parts = (hm ?? '').split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return h * 60 + m;
  }

  final rise = minutes(sunrise, 6 * 60);
  final set = minutes(sunset, 18 * 60);
  final t = now.hour * 60 + now.minute;
  if (t >= rise - 60 && t < rise + 60) return SkyTime.dawn;
  if (t >= set - 60 && t < set + 60) return SkyTime.dusk;
  if (t >= rise + 60 && t < set - 60) return SkyTime.day;
  return SkyTime.night;
}

/// 一套天色。onSky/onSkySoft 在运行时按对比度从墨色与纸色里择优。
class SkyPalette {
  final Color top, mid, horizon, ridge;
  final Color? orb; // 日或月
  final Color? precip; // 雨丝 / 雪点
  final bool night;

  const SkyPalette({
    required this.top,
    required this.mid,
    required this.horizon,
    required this.ridge,
    this.orb,
    this.precip,
    this.night = false,
  });

  static const _ink = Color(0xFF1F211E);
  static const _inkSoft = Color(0xFF3A3C37);
  static const _paper = Color(0xFFF1ECE1);
  static const _paperSoft = Color(0xFFCFC8BA);

  /// 文字区落在天顶到天中之间：取两者中更「难」的一端择色
  bool get darkText {
    final l = math.max(top.computeLuminance(), mid.computeLuminance());
    final lo = math.min(top.computeLuminance(), mid.computeLuminance());
    final inkC = (lo + 0.05) / (_ink.computeLuminance() + 0.05);
    final paperC = (_paper.computeLuminance() + 0.05) / (l + 0.05);
    return inkC >= paperC;
  }

  Color get onSky => darkText ? _ink : _paper;

  /// 次级文字：从柔和色向主文字色逼近，取第一档对天顶/天中都 ≥4.6 的颜色
  Color get onSkySoft {
    final soft = darkText ? _inkSoft : _paperSoft;
    for (var k = 0.0; k <= 1.0; k += 0.1) {
      final c = Color.lerp(soft, onSky, k)!;
      if (_ratio(c, top) >= 4.6 && _ratio(c, mid) >= 4.6) return c;
    }
    return onSky;
  }

  static double _ratio(Color a, Color b) {
    final l1 = a.computeLuminance(), l2 = b.computeLuminance();
    return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
  }

  static SkyPalette of(SkyCondition c, SkyTime t) {
    final base = _day[c]!;
    switch (t) {
      case SkyTime.day:
        return base;
      case SkyTime.night:
        return _night[c]!;
      case SkyTime.dawn:
      case SkyTime.dusk:
        // 晨暮：天顶压暗一档，天际染杏色；雨雪阴雾只染一点
        final warm = t == SkyTime.dusk
            ? const Color(0xFFE6B994)
            : const Color(0xFFEFCDB4);
        final strong = c == SkyCondition.clear || c == SkyCondition.cloudy;
        return SkyPalette(
          // 雨雪阴雾的天顶本就在中灰带，再压暗会让深浅文字都不达标，只染天际
          top: strong ? Color.lerp(base.top, const Color(0xFF5E6B80), 0.35)! : base.top,
          mid: Color.lerp(base.mid, warm, strong ? 0.35 : 0.15)!,
          horizon: Color.lerp(base.horizon, warm, strong ? 0.6 : 0.3)!,
          ridge: Color.lerp(base.ridge, const Color(0xFF3B3540), 0.3)!,
          orb: c == SkyCondition.clear
              ? (t == SkyTime.dusk ? const Color(0xFFC8664E) : const Color(0xFFE39A7E))
              : null,
          precip: base.precip,
        );
    }
  }

  static const _day = <SkyCondition, SkyPalette>{
    SkyCondition.clear: SkyPalette(
      top: Color(0xFFB7CDD2),
      mid: Color(0xFFD7E1DB),
      horizon: Color(0xFFF1EADB),
      ridge: Color(0xFF4F5E59),
      orb: Color(0xFFD9826B),
    ),
    SkyCondition.cloudy: SkyPalette(
      top: Color(0xFFBEC7C5),
      mid: Color(0xFFD6DAD3),
      horizon: Color(0xFFECE7DC),
      ridge: Color(0xFF55605C),
    ),
    SkyCondition.overcast: SkyPalette(
      top: Color(0xFFA3AAA9),
      mid: Color(0xFFBEC2BD),
      horizon: Color(0xFFDCD9D0),
      ridge: Color(0xFF4A5250),
    ),
    SkyCondition.fog: SkyPalette(
      top: Color(0xFFC9CCC7),
      mid: Color(0xFFD9DAD4),
      horizon: Color(0xFFE8E6DE),
      ridge: Color(0xFF7F8783),
    ),
    SkyCondition.rain: SkyPalette(
      top: Color(0xFF7C8B95),
      mid: Color(0xFF98A4AA),
      horizon: Color(0xFFBEC5C3),
      ridge: Color(0xFF38454D),
      precip: Color(0xFF3E4C55),
    ),
    SkyCondition.snow: SkyPalette(
      top: Color(0xFFCED6DC),
      mid: Color(0xFFE1E5E5),
      horizon: Color(0xFFF2F0EA),
      ridge: Color(0xFF76818A),
      precip: Color(0xFFFBFAF6),
    ),
  };

  static const _night = <SkyCondition, SkyPalette>{
    SkyCondition.clear: SkyPalette(
      top: Color(0xFF11151D),
      mid: Color(0xFF1B212A),
      horizon: Color(0xFF2E323A),
      ridge: Color(0xFF07090C),
      orb: Color(0xFFE9E1CC),
      night: true,
    ),
    SkyCondition.cloudy: SkyPalette(
      top: Color(0xFF15181E),
      mid: Color(0xFF1F2329),
      horizon: Color(0xFF2F3135),
      ridge: Color(0xFF08090B),
      orb: Color(0xFFCFC7B4),
      night: true,
    ),
    SkyCondition.overcast: SkyPalette(
      top: Color(0xFF17191C),
      mid: Color(0xFF212327),
      horizon: Color(0xFF303134),
      ridge: Color(0xFF09090A),
      night: true,
    ),
    SkyCondition.fog: SkyPalette(
      top: Color(0xFF1C1E21),
      mid: Color(0xFF272A2D),
      horizon: Color(0xFF38393A),
      ridge: Color(0xFF111214),
      night: true,
    ),
    SkyCondition.rain: SkyPalette(
      top: Color(0xFF0F141A),
      mid: Color(0xFF192027),
      horizon: Color(0xFF262E36),
      ridge: Color(0xFF06080A),
      precip: Color(0xFF9AA8B2),
      night: true,
    ),
    SkyCondition.snow: SkyPalette(
      top: Color(0xFF181D25),
      mid: Color(0xFF242A33),
      horizon: Color(0xFF383E48),
      ridge: Color(0xFF0B0D11),
      precip: Color(0xFFE4E7EC),
      night: true,
    ),
  };
}

/// 中文数字（-99..99），用于「十六度」「十一月三日」
String chineseNumber(int n) {
  const d = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (n < 0) return '零下${chineseNumber(-n)}';
  if (n < 10) return d[n];
  if (n < 20) return '十${n % 10 == 0 ? '' : d[n % 10]}';
  if (n < 100) return '${d[n ~/ 10]}十${n % 10 == 0 ? '' : d[n % 10]}';
  return '$n';
}

/// 计数用中文：2 读「两」（两笔、两天），其余同 [chineseNumber]
String chineseCount(int n) => n == 2 ? '两' : chineseNumber(n);

String chineseTemperature(int t) => '${chineseNumber(t)}度';

/// 一句天气短句（水汽感，不说教、不卖萌）。同一天内稳定，按日轮换。
String skyLine(SkyCondition c, SkyTime t, {int dayOfYear = 0}) {
  final night = t == SkyTime.night;
  final lines = switch (c) {
    SkyCondition.clear => night
        ? ['月亮出来了。', '晴夜，能看见几颗星。']
        : t == SkyTime.dusk
        ? ['太阳快落山了。', '天边有晚霞。']
        : t == SkyTime.dawn
        ? ['天刚亮，是个晴天。', '早上晴，空气凉。']
        : ['天很高，出门走走。', '太阳好，可以晒被子。', '晴，风不大。'],
    SkyCondition.cloudy => night
        ? ['云遮了半个月亮。']
        : ['云走得很慢。', '多云，不晒。', '有云，光线柔和。'],
    SkyCondition.overcast => night
        ? ['阴天，夜里看不见月亮。']
        : ['天压得低，适合待在屋里。', '阴天，屋里开盏灯。'],
    SkyCondition.fog => ['起雾了，远处看不清。', '有雾，路上慢点。'],
    SkyCondition.rain => night
        ? ['夜里下雨，听得见雨声。', '雨还在下，盖好被子。']
        : ['下雨了，出门带伞。', '雨下得密。', '下雨天，在屋里写几句。'],
    SkyCondition.snow => ['下雪了，路滑。', '下雪了，外面很安静。'],
  };
  return lines[dayOfYear % lines.length];
}

/// 点景：雨雪阴雾配孤舟，晴与多云配归帆（线稿见 assets/motifs/SOURCES.md）
String skyMotifFor(SkyCondition c) => switch (c) {
      SkyCondition.clear || SkyCondition.cloudy => 'assets/motifs/sail.png',
      _ => 'assets/motifs/boat.png',
    };

/// 天色分层：静态层只画一次，云整层平移，雨雪逐帧
enum SkyLayer { sky, clouds, mountains, precip, fade }

/// 笺头画画笔（木版套色）：刷色天 → 日月星 → 云 → 三层山（错版 + 侵蚀 + 断续勾线；近山只在右岸，
/// 左侧留出水面放点景，即「一河两岸」）→ 雨雪 → 淡入纸面。
/// [layers] 选择要画的层；每层用各自的随机种子，单画某层时位置与整画一致。
/// [grain]/[motif] 为空时照常绘制（无侵蚀、无点景），测试与首帧不依赖资源加载。
class WeatherSkyPainter extends CustomPainter {
  final SkyPalette palette;
  final SkyCondition condition;
  final Color paper; // 底部淡入的页面纸色
  final int seed;
  final Set<SkyLayer> layers;
  final Offset orbAt; // 日月位置（占画布比例）
  final Animation<double>? phase; // 雨雪下落相位（0..1 循环）
  final ui.Image? grain; // 纸纹：版面侵蚀
  final ui.Image? motif; // 点景线稿
  final Offset motifAt; // 点景底边中点（占画布比例）
  final double motifWidth; // 点景宽（占画布宽比例）

  WeatherSkyPainter({
    required this.palette,
    required this.condition,
    required this.paper,
    this.seed = 7,
    this.layers = const {...SkyLayer.values},
    this.orbAt = const Offset(0.8, 0.3),
    this.phase,
    this.grain,
    this.motif,
    this.motifAt = const Offset(0.27, 0.785),
    this.motifWidth = 0.2,
  }) : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    if (layers.contains(SkyLayer.sky)) _paintSky(canvas, size);
    if (layers.contains(SkyLayer.clouds)) paintClouds(canvas, size, dx: 0);
    if (layers.contains(SkyLayer.mountains)) _paintMountains(canvas, size);
    if (layers.contains(SkyLayer.precip)) _paintPrecip(canvas, size, phase?.value ?? 0);
    if (layers.contains(SkyLayer.fade)) _paintFade(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = palette;
    final rng = math.Random(seed * 7 + 1);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.top, p.mid, p.horizon, p.horizon],
          stops: const [0.0, 0.42, 0.74, 1.0],
        ).createShader(Offset.zero & size),
    );

    // 刷痕：上色时棕刷在版上留下的横向纹理（木版水印的手工痕迹）
    final darker = Color.lerp(p.top, p.ridge, 0.4)!;
    for (var i = 0; i < 18; i++) {
      final y = h * (0.02 + rng.nextDouble() * 0.55);
      final x0 = -20 + rng.nextDouble() * w * 0.7;
      final len = w * (0.25 + rng.nextDouble() * 0.7);
      canvas.drawLine(
        Offset(x0, y),
        Offset(x0 + len, y + (rng.nextDouble() - 0.5) * 5),
        Paint()
          ..color = (rng.nextDouble() < 0.6 ? darker : p.horizon).withAlpha(p.night ? 16 : 20)
          ..strokeWidth = 1.2 + rng.nextDouble() * 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 + rng.nextDouble() * 2.5),
      );
    }

    if (p.night && condition == SkyCondition.clear) {
      final star = Paint()..color = p.orb!.withAlpha(150);
      for (var i = 0; i < 26; i++) {
        final o = Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.42);
        canvas.drawCircle(o, 0.5 + rng.nextDouble() * 0.8, star);
      }
    }

    if (p.orb != null) {
      final c = Offset(w * orbAt.dx, h * (p.night ? orbAt.dy * 0.75 : orbAt.dy));
      final r = w * (p.night ? 0.05 : 0.068);
      final glowAlpha = condition == SkyCondition.cloudy ? 40 : 70;
      canvas.drawCircle(
        c,
        r * 3.2,
        Paint()
          ..shader = RadialGradient(
            colors: [p.orb!.withAlpha(glowAlpha), p.orb!.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: c, radius: r * 3.2)),
      );
      if (p.night) {
        final moon = Path()..addOval(Rect.fromCircle(center: c, radius: r));
        final bite = Path()
          ..addOval(Rect.fromCircle(center: c + Offset(r * 0.45, -r * 0.2), radius: r * 0.92));
        canvas.drawPath(
          Path.combine(PathOperation.difference, moon, bite),
          Paint()..color = p.orb!.withAlpha(condition == SkyCondition.cloudy ? 140 : 230),
        );
      } else {
        canvas.drawCircle(c, r, Paint()..color = p.orb!.withAlpha(215));
      }
    }
  }

  /// 云：横向晕开的淡墨/淡白团。[dx] 为整体平移（漂云用：画两份首尾相接）
  void paintClouds(Canvas canvas, Size size, {required double dx}) {
    final w = size.width, h = size.height;
    final p = palette;
    final rng = math.Random(seed * 7 + 2);
    final cloudCount = switch (condition) {
      SkyCondition.clear => 2,
      SkyCondition.cloudy => 6,
      SkyCondition.overcast || SkyCondition.rain || SkyCondition.snow => 8,
      SkyCondition.fog => 4,
    };
    final darkCloud = condition == SkyCondition.overcast || condition == SkyCondition.rain;
    for (var i = 0; i < cloudCount; i++) {
      final cw = w * (0.45 + rng.nextDouble() * 0.5);
      final ch = h * (0.035 + rng.nextDouble() * 0.05);
      final cx = rng.nextDouble() * w + dx;
      final cy = h * (0.08 + rng.nextDouble() * 0.42);
      final base = p.night
          ? p.horizon
          : darkCloud
          ? Color.lerp(p.top, p.ridge, 0.25)!
          : p.horizon;
      final alpha = p.night ? 60 : (darkCloud ? 70 : 150);
      final paint = Paint()
        ..color = base.withAlpha(condition == SkyCondition.clear ? alpha ~/ 2 : alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ch * 0.7);
      for (final shift in [0.0, w]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + shift, cy), width: cw, height: ch),
          paint,
        );
      }
    }
  }

  void _paintMountains(Canvas canvas, Size size) {
    final h = size.height;
    final p = palette;
    final rng = math.Random(seed * 7 + 3);
    final fog = condition == SkyCondition.fog;
    // 远 / 中 / 近三版。近山只占右岸，左侧留水面（一河两岸），点景落在中山脚下的水上
    final layers = [
      (base: 0.62, amp: 0.12, alpha: fog ? 0.16 : 0.24, line: 0.0, width: 0.0, peaks: 4, from: 0.0, to: 1.0, floor: 0.18),
      (base: 0.71, amp: 0.13, alpha: fog ? 0.26 : 0.44, line: fog ? 0.14 : 0.3, width: 0.8, peaks: 3, from: 0.0, to: 1.0, floor: 0.18),
      (base: 0.83, amp: 0.15, alpha: fog ? 0.38 : 0.74, line: fog ? 0.22 : 0.5, width: 1.1, peaks: 2, from: 0.5, to: 1.02, floor: 0.05),
    ];
    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      _ridge(canvas, size, rng, h * l.base, h * l.amp, p.ridge, l.alpha,
          peaks: l.peaks, from: l.from, to: l.to, floor: l.floor, line: l.line, lineWidth: l.width);
      _mist(canvas, size, h * (l.base + 0.035), h * (fog ? 0.12 : 0.07),
          p.horizon.withAlpha(fog ? 210 : 150));
      if (i == 1) _paintMotif(canvas, size);
    }
  }

  /// 点景：线稿染成山色（夜里染成天上文字的柔色，像月光勾出的轮廓），舟下几笔水纹
  void _paintMotif(Canvas canvas, Size size) {
    final img = motif;
    if (img == null) return;
    final w = size.width, h = size.height, p = palette;
    final mw = w * motifWidth;
    final mh = mw * img.height / img.width;
    final cx = w * motifAt.dx, bottom = h * motifAt.dy;
    final tint = p.night
        ? p.onSkySoft.withAlpha(150)
        : Color.lerp(p.ridge, const Color(0xFF000000), 0.2)!.withAlpha(215);
    canvas.drawImageRect(
      img,
      Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(cx - mw / 2, bottom - mh, mw, mh),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn),
    );
    final r = math.Random(seed * 7 + 5);
    final water = Paint()
      ..color = tint.withAlpha((tint.a * 255 * 0.35).round())
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = bottom + 2.5 + i * 3 + r.nextDouble() * 1.5;
      final x = cx - mw * 0.55 + r.nextDouble() * mw * 0.9;
      canvas.drawLine(Offset(x, y), Offset(x + mw * (0.06 + r.nextDouble() * 0.14), y), water);
    }
  }

  /// 雨丝 / 雪点。[t] 为下落相位：雨每圈落一个画布高，雪缓落并左右轻摆
  void _paintPrecip(Canvas canvas, Size size, double t) {
    final p = palette;
    if (p.precip == null) return;
    final w = size.width, h = size.height;
    final rng = math.Random(seed * 7 + 4);
    final top = -h * 0.05, span = h * 0.95;
    if (condition == SkyCondition.rain) {
      final rain = Paint()
        ..color = p.precip!.withAlpha(p.night ? 70 : 85)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      final n = (w * h / 2400).round();
      for (var i = 0; i < n; i++) {
        final x0 = rng.nextDouble() * (w + 60) - 20;
        final y0 = rng.nextDouble();
        final speed = 0.8 + rng.nextDouble() * 0.5;
        final len = 9 + rng.nextDouble() * 10;
        final f = (y0 + t * speed) % 1.0;
        final y = top + f * span;
        final x = x0 - f * span * 0.26; // 斜落
        canvas.drawLine(Offset(x, y), Offset(x - len * 0.26, y + len), rain);
      }
    } else if (condition == SkyCondition.snow) {
      final flake = Paint()..color = p.precip!.withAlpha(210);
      final n = (w * h / 3200).round();
      for (var i = 0; i < n; i++) {
        final x0 = rng.nextDouble() * w;
        final y0 = rng.nextDouble();
        final r = 0.9 + rng.nextDouble() * 1.6;
        final f = (y0 + t * (0.6 + r * 0.15)) % 1.0;
        final sway = math.sin((f * 6 + y0 * 10) * math.pi) * 6;
        canvas.drawCircle(Offset(x0 + sway, top + f * span), r, flake);
      }
    }
  }

  void _paintFade(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 夜天落在浅纸上反差大：雾起得更早更快，避免深浅混成脏灰
    final contrasty = (palette.top.computeLuminance() - paper.computeLuminance()).abs() > 0.5;
    final fadeTop = contrasty ? 0.8 : 0.78;
    final fade = Rect.fromLTWH(0, h * fadeTop, w, h * (1 - fadeTop) + 1);
    canvas.drawRect(
      fade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [paper.withAlpha(0), paper.withAlpha(contrasty ? 235 : 200), paper],
          stops: [0.0, contrasty ? 0.32 : 0.6, 1.0],
        ).createShader(fade),
    );
  }

  /// 山脊：若干不对称峰（主峰 + 侧峰 + 缓坡）取最高包络，叠细碎山脊纹与刻刀抖动；
  /// 色版竖向渐变（浓脊淡脚）并相对线版错开一点（套印不准），版面按纸纹侵蚀；
  /// [line] > 0 时再压一道断续的山脊墨线（线版，飞白处断开）。峰只落在 [from]..[to] 宽度区间。
  void _ridge(Canvas canvas, Size size, math.Random rng, double baseY, double amp,
      Color color, double alpha,
      {required int peaks,
      double from = 0,
      double to = 1,
      double floor = 0.18,
      double line = 0,
      double lineWidth = 1}) {
    final w = size.width;
    final ridgePeaks = List.generate(peaks, (i) {
      final cx = w * (from + (to - from) * (i + 0.2 + rng.nextDouble() * 0.6) / peaks);
      return (
        cx: cx,
        height: 0.55 + rng.nextDouble() * 0.45,
        left: w * (0.16 + rng.nextDouble() * 0.2),
        right: w * (0.16 + rng.nextDouble() * 0.2),
      );
    });
    final ph = rng.nextDouble() * math.pi * 2;
    double yAt(double x) {
      var hgt = floor; // 连绵的低缓山体
      for (final pk in ridgePeaks) {
        final d = x - pk.cx;
        final span = d < 0 ? pk.left : pk.right;
        final t = (d.abs() / span).clamp(0.0, 1.0);
        // 平滑钟形，峰顶略尖：(1 - t^1.6)^2.2
        final bell = math.pow(1 - math.pow(t, 1.6), 2.2).toDouble();
        hgt = math.max(hgt, pk.height * bell);
      }
      final texture = math.sin(x / w * math.pi * 19 + ph) * 0.03 +
          math.sin(x / w * math.pi * 41 + ph * 1.7) * 0.008;
      return baseY - amp * (hgt + texture);
    }

    final pts = <Offset>[];
    var minY = size.height;
    for (var x = 0.0; x <= w + 3; x += 3) {
      final y = yAt(x) + (rng.nextDouble() - 0.5) * 1.4; // 刻刀走线不是数学曲线
      minY = math.min(minY, y);
      pts.add(Offset(x, y));
    }
    final path = Path()..moveTo(0, size.height);
    for (final pt in pts) {
      path.lineTo(pt.dx, pt.dy);
    }
    path
      ..lineTo(w, size.height)
      ..close();
    final rect = Rect.fromLTRB(0, minY, w, baseY + amp * 0.9);
    final shift = Offset((rng.nextDouble() - 0.5) * 2.4, (rng.nextDouble() - 0.5) * 1.8);
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha((alpha * 255).round()),
            color.withAlpha((alpha * 0.6 * 255).round()),
            color.withAlpha(0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    canvas.restore();
    final img = grain;
    if (img != null) {
      XqPaper.erode(canvas, bounds, img, strength: 0.55, scale: 0.5, shift: Offset(baseY, baseY * 0.7));
    }
    canvas.restore();

    if (line <= 0) return;
    final p = palette;
    final ink = p.night ? Color.lerp(p.horizon, p.onSkySoft, 0.25)! : color;
    final stroke = Paint()
      ..color = ink.withAlpha((line * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dryPh = rng.nextDouble() * 10;
    final seg = Path();
    var pen = false;
    for (var i = 0; i < pts.length; i++) {
      // 飞白：两道不同频率的起伏同时走低处断笔
      final dry = math.sin(i * 0.37 + dryPh) + math.sin(i * 0.113 + dryPh * 2) < -1.15;
      if (dry) {
        pen = false;
        continue;
      }
      pen ? seg.lineTo(pts[i].dx, pts[i].dy) : seg.moveTo(pts[i].dx, pts[i].dy);
      pen = true;
    }
    canvas.drawPath(seg, stroke);
  }

  void _mist(Canvas canvas, Size size, double y, double hgt, Color color) {
    final rect = Rect.fromLTWH(0, y - hgt / 2, size.width, hgt);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(0), color, color.withAlpha(0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(WeatherSkyPainter old) =>
      old.palette != palette ||
      old.condition != condition ||
      old.paper != paper ||
      old.seed != seed ||
      old.orbAt != orbAt ||
      old.grain != grain ||
      old.motif != motif ||
      old.motifAt != motifAt ||
      old.motifWidth != motifWidth ||
      !setEquals(old.layers, layers);
}

/// 会动的天：云慢漂、雨雪下落；滚动时远山比天空移得快（景深视差）。
/// 只有雨雪层逐帧重绘，天空/远山静态缓存，云整层平移。
/// 减弱动效时静止；离屏（TickerMode 关闭）时自动暂停。
class WeatherSkyScene extends StatefulWidget {
  final SkyPalette palette;
  final SkyCondition condition;
  final Color paper;
  final int seed;
  final Offset orbAt;
  final ScrollController? scroll; // 提供则做视差
  final bool fade; // 底部淡入纸面（无面板覆盖时用）
  final String? motif; // 点景线稿资源；null 不画
  final Offset motifAt;
  final double motifWidth;

  const WeatherSkyScene({
    super.key,
    required this.palette,
    required this.condition,
    required this.paper,
    this.seed = 7,
    this.orbAt = const Offset(0.8, 0.3),
    this.scroll,
    this.fade = false,
    this.motif,
    this.motifAt = const Offset(0.27, 0.785),
    this.motifWidth = 0.2,
    this.reveal = false,
  });

  /// 进入时按版序「套印显影」（约 1.4s）；首页每天第一次打开时为 true
  final bool reveal;

  @override
  State<WeatherSkyScene> createState() => _WeatherSkySceneState();
}

class _WeatherSkySceneState extends State<WeatherSkyScene>
    with TickerProviderStateMixin {
  AnimationController? _drift;
  AnimationController? _fall;
  bool? _reduce;
  ui.Image? _motif;
  String? _motifAsset;
  AnimationController? _reveal;

  @override
  void initState() {
    super.initState();
    XqPaper.ensureLoaded();
    _loadMotif();
    if (widget.reveal) {
      _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _reveal!.value = 1;
        } else {
          _reveal!.forward();
        }
      });
    }
  }

  void _loadMotif() {
    final asset = widget.motif;
    if (asset == _motifAsset) return;
    _motifAsset = asset;
    _motif = null;
    if (asset == null) return;
    XqPaper.loadImage(asset).then((img) {
      if (mounted && _motifAsset == asset) setState(() => _motif = img);
    }, onError: (_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WeatherSkyScene old) {
    super.didUpdateWidget(old);
    if (old.condition != widget.condition) _sync(force: true);
    _loadMotif();
  }

  void _sync({bool force = false}) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!force && reduce == _reduce) return;
    _reduce = reduce;
    _drift?.dispose();
    _fall?.dispose();
    _drift = null;
    _fall = null;
    if (reduce) return;
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 140))
      ..repeat();
    final fallMs = switch (widget.condition) {
      SkyCondition.rain => 1100,
      SkyCondition.snow => 14000,
      _ => 0,
    };
    if (fallMs > 0) {
      _fall = AnimationController(vsync: this, duration: Duration(milliseconds: fallMs))
        ..repeat();
    }
  }


  WeatherSkyPainter _painter(Set<SkyLayer> layers, {Animation<double>? phase, ui.Image? grain}) =>
      WeatherSkyPainter(
        palette: widget.palette,
        condition: widget.condition,
        paper: widget.paper,
        seed: widget.seed,
        orbAt: widget.orbAt,
        layers: layers,
        phase: phase,
        grain: grain,
        motif: _motif,
        motifAt: widget.motifAt,
        motifWidth: widget.motifWidth,
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ui.Image?>(
      valueListenable: XqPaper.image,
      builder: (context, grain, _) => _scene(context, grain),
    );
  }

  // ── 静态层烘焙成位图：Impeller 没有光栅缓存，图层合成与纹理侵蚀若留在 CustomPaint 里会每帧重放 ──
  final _baked = <SkyLayer, (String, ui.Image)>{};

  ui.Image _bake(SkyLayer layer, String key, Size size, double scale, void Function(Canvas) paint) {
    final hit = _baked[layer];
    if (hit != null && hit.$1 == key) return hit.$2;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..scale(scale);
    paint(canvas);
    final pic = rec.endRecording();
    final img = pic.toImageSync(math.max(1, (size.width * scale).ceil()), math.max(1, (size.height * scale).ceil()));
    pic.dispose();
    hit?.$2.dispose(); // RawImage 持有的是 clone，旧图可以放心释放
    _baked[layer] = (key, img);
    return img;
  }

  String _key(Size size, double dpr, ui.Image? grain) {
    final p = widget.palette;
    return [
      widget.condition.index, widget.seed, size.width.round(), size.height.round(), dpr,
      p.top.toARGB32(), p.mid.toARGB32(), p.horizon.toARGB32(), p.ridge.toARGB32(), p.orb?.toARGB32(),
      widget.orbAt, widget.motifAt, widget.motifWidth, widget.paper.toARGB32(),
      identityHashCode(grain), identityHashCode(_motif),
    ].join('|');
  }

  void _grainOver(Canvas canvas, Size size, ui.Image? grain, {bool atop = false}) {
    if (grain == null) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = XqPaper.shader(grain)
        ..colorFilter = ColorFilter.mode(
          widget.palette.night ? const Color(0x0EE6ECF4) : const Color(0x14403020),
          BlendMode.srcIn,
        )
        ..blendMode = atop ? BlendMode.srcATop : BlendMode.srcOver,
    );
  }

  @override
  void dispose() {
    for (final e in _baked.values) {
      e.$2.dispose();
    }
    _reveal?.dispose();
    _drift?.dispose();
    _fall?.dispose();
    super.dispose();
  }

  Widget _scene(BuildContext context, ui.Image? grain) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        if (size.isEmpty) return const SizedBox.shrink();
        final w = size.width;
        final dpr = math.min(MediaQuery.devicePixelRatioOf(context), 2.5);
        final key = _key(size, dpr, grain);

        // 天（含纸纹）、山（纸纹只落在山上）按屏幕密度烘焙；云本身是糊的，1 倍即可，宽两屏以便循环漂移
        final skyImg = _bake(SkyLayer.sky, key, size, dpr, (cv) {
          _painter({SkyLayer.sky}).paint(cv, size);
          _grainOver(cv, size, grain);
        });
        final mountainImg = _bake(SkyLayer.mountains, key, size, dpr, (cv) {
          _painter({SkyLayer.mountains}, grain: grain).paint(cv, size);
          _grainOver(cv, size, grain, atop: true);
        });
        final cloudImg = _bake(SkyLayer.clouds, key, Size(w * 2, size.height), 1, (cv) {
          _painter({SkyLayer.clouds}).paintClouds(cv, size, dx: 0);
        });

        Widget image(ui.Image img) => RawImage(image: img, fit: BoxFit.fill, filterQuality: FilterQuality.low);
        final sky = SizedBox.expand(child: image(skyImg));
        final mountains = SizedBox.expand(child: image(mountainImg));
        Widget clouds = OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: w * 2,
          minWidth: w * 2,
          child: image(cloudImg),
        );
        final drift = _drift;
        if (drift != null) {
          final still = clouds;
          clouds = AnimatedBuilder(
            animation: drift,
            child: still,
            builder: (_, child) => Transform.translate(offset: Offset(-drift.value * w, 0), child: child),
          );
        }
        final precip = widget.palette.precip == null
            ? null
            : RepaintBoundary(child: CustomPaint(painter: _painter({SkyLayer.precip}, phase: _fall)));

        final scroll = widget.scroll;
        Widget layer(double k, Widget child) {
          if (scroll == null) return child;
          return AnimatedBuilder(
            animation: scroll,
            child: child,
            builder: (_, child) {
              final y = scroll.hasClients ? scroll.offset.clamp(0.0, 2000.0) : 0.0;
              return Transform.translate(offset: Offset(0, -y * k), child: child);
            },
          );
        }

        // 套印显影：天 → 云 → 山（带一点对版的横移）→ 雨雪，依版序显出
        final reveal = _reveal;
        Widget print(double from, double to, Widget child, {double shift = 0}) {
          if (reveal == null) return child;
          final t = CurvedAnimation(parent: reveal, curve: Interval(from, to, curve: Curves.easeOutQuart));
          return AnimatedBuilder(
            animation: t,
            child: child,
            builder: (_, child) => Opacity(
              opacity: t.value,
              child: shift == 0 ? child : Transform.translate(offset: Offset((1 - t.value) * shift, 0), child: child),
            ),
          );
        }

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              layer(0.25, print(0, 0.35, sky)),
              layer(0.3, print(0.15, 0.5, clouds)),
              layer(0.5, print(0.3, 0.75, mountains, shift: 4)),
              if (precip != null) print(0.6, 1, precip),
              if (widget.fade)
                IgnorePointer(child: CustomPaint(painter: _painter({SkyLayer.fade}))),
            ],
          ),
        );
      },
    );
  }
}
