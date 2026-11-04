import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../stores/theme_state.dart';
import '../../theme/xq_palette.dart';
import 'xq_kit.dart';
import 'xq_paper.dart';

/// 换纸过渡：换纸那一刻把旧画面截下来盖在最上层，新纸从点按处像墨一样晕开，
/// 边缘不规则（不是正圆）。没有点按位置（跟随系统自动切换）时只做淡出。
/// 只在最上层画一张图 + 一次裁剪，下面的页面按新颜色正常重建，不逐帧插值几十个颜色。
/// 从「我」页纸样换纸时，墨晕开后居中浮出一张小笺，竖排讲这张纸的来历，停一会儿自己淡去（点一下就收）。
class XqThemeReveal extends StatefulWidget {
  const XqThemeReveal({super.key, required this.child});
  final Widget child;

  /// 过渡层的 key（测试用来判断过渡层在不在）
  static const overlayKey = ValueKey('xq-theme-reveal-overlay');

  /// 纸的来历小笺的 key
  static const storyKey = ValueKey('xq-theme-reveal-story');

  @override
  State<XqThemeReveal> createState() => _XqThemeRevealState();
}

class _XqThemeRevealState extends State<XqThemeReveal> with TickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _c = AnimationController(vsync: this);
  late final AnimationController _storyC = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  XqPalette? _story;
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
    final story = t.storyPaper;
    t.storyPaper = null;
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
    if (story != null) _tellStory(story);
    _c.duration = Duration(milliseconds: _origin == null ? 260 : 640);
    _c.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() {
        _old?.dispose();
        _old = null;
      });
    });
  }

  void _tellStory(XqPalette p) {
    setState(() => _story = p);
    _storyC.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) setState(() => _story = null);
    });
  }

  void _dismissStory() {
    if (_storyC.value < 0.85) _storyC.animateTo(1, duration: const Duration(milliseconds: 240));
  }

  @override
  void dispose() {
    _theme?.removeListener(_onTheme);
    _storyC.dispose();
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
        if (_story != null)
          Positioned.fill(
            key: XqThemeReveal.storyKey,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissStory,
              child: _PaperStory(paper: _story!, t: _storyC, reduce: MediaQuery.disableAnimationsOf(context)),
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

/// 换纸时浮出的小笺：右起纸名竖写 + 一枚纸名首字印，左边两列来历。
/// 0.12–0.24 浮现（上移 10px），停到 0.84，之后淡去。
class _PaperStory extends StatelessWidget {
  const _PaperStory({required this.paper, required this.t, required this.reduce});
  final XqPalette paper;
  final Animation<double> t;
  final bool reduce;

  Widget _vertical(String text, TextStyle style) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final ch in text.characters)
            ch == '，' ? const SizedBox(height: 12) : Text(ch, style: style),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final p = paper;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
      decoration: BoxDecoration(
        color: p.card,
        image: XqPaper.grain(p.fiber, strength: p.dark ? 0.6 : 0.8),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: p.frame, width: 0.6),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(p.dark ? 90 : 34), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in p.legend.reversed) ...[
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: _vertical(line, TextStyle(fontFamily: 'Display', fontSize: 15, height: 1.3, color: p.textSecondary)),
            ),
            const SizedBox(width: 14),
          ],
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _vertical(p.name, TextStyle(fontFamily: 'Display', fontSize: 30, height: 1.2, color: p.textPrimary)),
              const SizedBox(height: 14),
              XqSeal(char: p.name.characters.first, color: p.seal, size: 30, style: XqSealStyle.bai),
            ],
          ),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) {
        final v = t.value;
        final inT = Curves.easeOutQuart.transform(((v - 0.12) / 0.12).clamp(0.0, 1.0));
        final outT = ((v - 0.84) / 0.16).clamp(0.0, 1.0);
        final opacity = (inT * (1 - outT)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: ColoredBox(
            // 一层很淡的纸色压住底下的页面，让小笺浮出来
            color: p.background.withAlpha(110),
            child: Transform.translate(offset: Offset(0, reduce ? 0 : 10 * (1 - inT)), child: child),
          ),
        );
      },
      // 小笺浮在 Navigator 之上，没有 Material 祖先：自己给一层透明 Material，文字才不带黄色下划线
      child: Material(
        type: MaterialType.transparency,
        child: Center(child: Semantics(liveRegion: true, label: '${p.name}。${p.story}', excludeSemantics: true, child: card)),
      ),
    );
  }
}
