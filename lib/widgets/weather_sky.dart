import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 天色：首页主视觉。随真实天气（6 种）与时辰（4 段）变化的一幅水墨天。
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

String chineseTemperature(int t) => '${chineseNumber(t)}度';

/// 一句天气短句（水汽感，不说教、不卖萌）。同一天内稳定，按日轮换。
String skyLine(SkyCondition c, SkyTime t, {int dayOfYear = 0}) {
  final night = t == SkyTime.night;
  final lines = switch (c) {
    SkyCondition.clear => night
        ? ['月亮出来了，早点睡。', '夜里晴，星星不多也不少。']
        : t == SkyTime.dusk
        ? ['太阳落得慢，晚霞还在。', '天边染了一点杏色。']
        : t == SkyTime.dawn
        ? ['天刚亮，今天是晴的。', '早上的光很干净。']
        : ['天很高，适合出门走走。', '阳光正好，把被子晒一晒。', '晴，风也轻。'],
    SkyCondition.cloudy => night
        ? ['云遮了一半月亮，夜色很软。']
        : ['云走得慢，心也可以慢一点。', '多云，光是软的。', '云在天上写字，你在地上写。'],
    SkyCondition.overcast => night
        ? ['夜里阴，没有月亮也没关系。']
        : ['天低低的，适合待在屋里。', '阴天，把灯开亮一点。'],
    SkyCondition.fog => ['雾把远处藏起来了，看近一点。', '起雾了，路上慢些。'],
    SkyCondition.rain => night
        ? ['夜雨，窗外有声音陪你。', '雨还在下，盖好被子。']
        : ['下雨了，记得带伞。', '雨声很密，适合写几句。', '听雨的时候，什么都可以不想。'],
    SkyCondition.snow => ['下雪了，走路慢一点。', '雪落无声，今天很安静。'],
  };
  return lines[dayOfYear % lines.length];
}

/// 天色分层：静态层只画一次，云整层平移，雨雪逐帧
enum SkyLayer { sky, clouds, mountains, precip, fade }

/// 水墨天色画笔：渐变天 → 日月星 → 云 → 三层远山（浓脊淡脚）+ 雾 → 雨雪 → 淡入纸面。
/// [layers] 选择要画的层；每层用各自的随机种子，单画某层时位置与整画一致。
class WeatherSkyPainter extends CustomPainter {
  final SkyPalette palette;
  final SkyCondition condition;
  final Color paper; // 底部淡入的页面纸色
  final int seed;
  final Set<SkyLayer> layers;
  final Offset orbAt; // 日月位置（占画布比例）
  final Animation<double>? phase; // 雨雪下落相位（0..1 循环）

  WeatherSkyPainter({
    required this.palette,
    required this.condition,
    required this.paper,
    this.seed = 7,
    this.layers = const {...SkyLayer.values},
    this.orbAt = const Offset(0.8, 0.3),
    this.phase,
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
    final layers = [
      (base: 0.64, amp: 0.13, alpha: fog ? 0.16 : 0.26),
      (base: 0.73, amp: 0.13, alpha: fog ? 0.26 : 0.46),
      (base: 0.83, amp: 0.12, alpha: fog ? 0.38 : 0.7),
    ];
    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      _ridge(canvas, size, rng, h * l.base, h * l.amp, p.ridge, l.alpha,
          peaks: i == 0 ? 4 : (i == 1 ? 3 : 2));
      _mist(canvas, size, h * (l.base + 0.035), h * (fog ? 0.12 : 0.07),
          p.horizon.withAlpha(fog ? 210 : 150));
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

  /// 山脊：若干不对称峰（主峰 + 侧峰 + 缓坡）取最高包络，叠细碎山脊纹；
  /// 竖向渐变上色：脊线浓、山脚淡入雾（水墨「浓脊淡脚」）
  void _ridge(Canvas canvas, Size size, math.Random rng, double baseY, double amp,
      Color color, double alpha, {required int peaks}) {
    final w = size.width;
    final ridgePeaks = List.generate(peaks, (i) {
      final cx = w * (i + 0.2 + rng.nextDouble() * 0.6) / peaks;
      return (
        cx: cx,
        height: 0.55 + rng.nextDouble() * 0.45,
        left: w * (0.16 + rng.nextDouble() * 0.2),
        right: w * (0.16 + rng.nextDouble() * 0.2),
      );
    });
    final ph = rng.nextDouble() * math.pi * 2;
    double yAt(double x) {
      var hgt = 0.18; // 远处连绵的低缓山体
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

    final path = Path()..moveTo(0, size.height);
    var minY = size.height;
    for (var x = 0.0; x <= w + 3; x += 3) {
      final y = yAt(x);
      minY = math.min(minY, y);
      path.lineTo(x, y);
    }
    path
      ..lineTo(w, size.height)
      ..close();
    final rect = Rect.fromLTRB(0, minY, w, baseY + amp * 0.9);
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

  const WeatherSkyScene({
    super.key,
    required this.palette,
    required this.condition,
    required this.paper,
    this.seed = 7,
    this.orbAt = const Offset(0.8, 0.3),
    this.scroll,
    this.fade = false,
  });

  @override
  State<WeatherSkyScene> createState() => _WeatherSkySceneState();
}

class _WeatherSkySceneState extends State<WeatherSkyScene>
    with TickerProviderStateMixin {
  AnimationController? _drift;
  AnimationController? _fall;
  bool? _reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WeatherSkyScene old) {
    super.didUpdateWidget(old);
    if (old.condition != widget.condition) _sync(force: true);
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

  @override
  void dispose() {
    _drift?.dispose();
    _fall?.dispose();
    super.dispose();
  }

  WeatherSkyPainter _painter(Set<SkyLayer> layers, {Animation<double>? phase}) =>
      WeatherSkyPainter(
        palette: widget.palette,
        condition: widget.condition,
        paper: widget.paper,
        seed: widget.seed,
        orbAt: widget.orbAt,
        layers: layers,
        phase: phase,
      );

  @override
  Widget build(BuildContext context) {
    final sky = RepaintBoundary(child: CustomPaint(painter: _painter({SkyLayer.sky})));
    final mountains = RepaintBoundary(child: CustomPaint(painter: _painter({SkyLayer.mountains})));
    final clouds = RepaintBoundary(child: CustomPaint(painter: _painter({SkyLayer.clouds})));
    final precip = widget.palette.precip == null
        ? null
        : CustomPaint(painter: _painter({SkyLayer.precip}, phase: _fall));

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        Widget drifting = clouds;
        final drift = _drift;
        if (drift != null) {
          drifting = AnimatedBuilder(
            animation: drift,
            child: clouds,
            builder: (_, child) => Transform.translate(
              offset: Offset(-drift.value * w, 0),
              child: child,
            ),
          );
        }
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

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              layer(0.25, sky),
              layer(0.3, drifting),
              layer(0.5, mountains),
              ?precip,
              if (widget.fade)
                IgnorePointer(child: CustomPaint(painter: _painter({SkyLayer.fade}))),
            ],
          ),
        );
      },
    );
  }
}
