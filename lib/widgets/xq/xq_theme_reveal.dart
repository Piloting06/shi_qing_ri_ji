import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../stores/theme_state.dart';

/// 换纸过渡：换纸那一刻把旧画面截下来盖在最上层，新纸从点按处像墨一样晕开，
/// 边缘不规则（不是正圆）。没有点按位置（跟随系统自动切换）时只做淡出。
/// 只在最上层画一张图 + 一次裁剪，下面的页面按新颜色正常重建，不逐帧插值几十个颜色。
class XqThemeReveal extends StatefulWidget {
  const XqThemeReveal({super.key, required this.child});
  final Widget child;

  /// 过渡层的 key（测试用来判断过渡层在不在）
  static const overlayKey = ValueKey('xq-theme-reveal-overlay');

  @override
  State<XqThemeReveal> createState() => _XqThemeRevealState();
}

class _XqThemeRevealState extends State<XqThemeReveal> with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _c = AnimationController(vsync: this);
  ThemeState? _theme;
  String? _lastId;
  bool _lastLoaded = false;
  ui.Image? _old;
  Offset? _origin;
  int _seed = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = Provider.of<ThemeState>(context, listen: false);
    if (t != _theme) {
      _theme?.removeListener(_onTheme);
      _theme = t..addListener(_onTheme);
      _lastId = t.palette.id;
      _lastLoaded = t.loaded;
    }
  }

  void _onTheme() {
    final t = _theme!;
    final id = t.palette.id;
    final origin = t.revealOrigin;
    t.revealOrigin = null;
    // 启动时从本地读出偏好那一下不做动画
    if (!_lastLoaded || !t.loaded) {
      _lastLoaded = t.loaded;
      _lastId = id;
      return;
    }
    if (id == _lastId) return;
    _lastId = id;

    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !box.hasSize) return;
    ui.Image img;
    try {
      // 通知发生在本帧重建之前，此刻边界里还是旧颜色的画面
      img = box.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context));
    } catch (_) {
      return;
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    _old?.dispose();
    setState(() {
      _old = img;
      _origin = reduce ? null : origin;
      _seed++;
    });
    _c.duration = Duration(milliseconds: _origin == null ? 260 : 640);
    _c.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() {
        _old?.dispose();
        _old = null;
      });
    });
  }

  @override
  void dispose() {
    _theme?.removeListener(_onTheme);
    _c.dispose();
    _old?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (old != null)
          Positioned.fill(
            key: XqThemeReveal.overlayKey,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RevealPainter(old, _origin, _c, _seed),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.image, this.origin, this.t, this.seed) : super(repaint: t);
  final ui.Image image;
  final Offset? origin;
  final Animation<double> t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Offset.zero & size;
    final v = t.value;
    final o = origin;
    if (o == null) {
      final paint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, 1 - Curves.easeOut.transform(v))
        ..filterQuality = FilterQuality.low;
      canvas.drawImageRect(image, src, dst, paint);
      return;
    }
    // 晕开半径：先快后慢；略超过最远角，保证最后完全铺满
    final far = [dst.topLeft, dst.topRight, dst.bottomLeft, dst.bottomRight]
        .map((c) => (c - o).distance)
        .reduce(math.max);
    final r = far * 1.12 * Curves.easeOutCubic.transform(v);
    final hole = _inkBlot(o, r, seed);
    final clip = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(dst)
      ..addPath(hole, Offset.zero);
    canvas.save();
    canvas.clipPath(clip);
    // 收尾 15% 让残边淡掉，不在最后一帧硬切
    final fade = v < 0.85 ? 1.0 : 1 - (v - 0.85) / 0.15;
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, fade)
        ..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  /// 墨晕：半径随角度起伏的闭合曲线（三组正弦叠加），像墨在纸纤维里洇开
  static Path _inkBlot(Offset c, double r, int seed) {
    final rnd = math.Random(seed * 7919);
    final p1 = rnd.nextDouble() * math.pi * 2;
    final p2 = rnd.nextDouble() * math.pi * 2;
    final p3 = rnd.nextDouble() * math.pi * 2;
    const n = 96;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final a = i / n * math.pi * 2;
      final k = 1 +
          0.045 * math.sin(a * 3 + p1) +
          0.03 * math.sin(a * 7 + p2) +
          0.018 * math.sin(a * 13 + p3);
      final pt = c + Offset(math.cos(a), math.sin(a)) * (r * k);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.image != image || old.origin != origin || old.seed != seed;
}
