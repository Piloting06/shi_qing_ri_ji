import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../stores/theme_state.dart';

/// 纸（P9 笺谱）：宣纸纹理、毛边、颜料。
///
/// 纹理 `assets/textures/paper.png`（scripts/gen_paper.py 生成）：RGB 恒白，alpha 即纤维与颗粒强度，
/// 可无缝平铺。两种用法：
/// - 组件：[XqPaper.grain] 产出 DecorationImage（染色 + 平铺），随组件一起滚动
/// - 画笔：[XqPaper.image] 解码后的位图，给天色版画、印章、颜料做侵蚀
class XqPaper {
  XqPaper._();

  static const asset = 'assets/textures/paper.png';
  static const _tile = AssetImage(asset);

  /// 解码后的纹理；未加载完时为 null，画笔应照常绘制、只是不做侵蚀
  static final ValueNotifier<ui.Image?> image = ValueNotifier(null);
  static Future<void>? _loading;

  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      image.value = await loadImage(asset);
    } catch (_) {
      // 纹理是锦上添花，加载失败不影响功能
    }
  }

  static final _cache = <String, Future<ui.Image>>{};

  /// 资源位图（点景线稿等），按路径缓存
  static Future<ui.Image> loadImage(String path) => _cache[path] ??= () async {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      }();

  /// 纸纹 DecorationImage：纹理按 [fiber] 染色，[strength] 0–1 控制浓淡。
  /// 512px 纹理按 2 倍密度铺（每块 256 逻辑像素），纤维细而不糊。
  static DecorationImage grain(Color fiber, {double strength = 1}) => DecorationImage(
        image: _tile,
        repeat: ImageRepeat.repeat,
        scale: 2,
        alignment: Alignment.topLeft,
        filterQuality: FilterQuality.medium,
        colorFilter: ColorFilter.mode(
          fiber.withAlpha((44 * strength).round().clamp(0, 255)),
          BlendMode.srcIn,
        ),
      );

  /// 画笔里用的平铺纹理着色器；[scale] 为纹理像素 → 逻辑像素的缩放，[shift] 错开不同印章/颜料的纹理
  static Shader shader(ui.Image img, {double scale = 0.5, Offset shift = Offset.zero}) => ImageShader(
        img,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()
              ..translateByDouble(shift.dx, shift.dy, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1))
            .storage,
      );

  /// 在已画好的层上按纹理侵蚀（dstOut）：印泥没吃上的地方、版画没印实的地方。
  /// 调用方负责 saveLayer，使侵蚀只作用于该层。
  static void erode(Canvas canvas, Rect rect, ui.Image img,
      {double strength = 0.6, double scale = 0.5, Offset shift = Offset.zero}) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader(img, scale: scale, shift: shift)
        ..colorFilter = ColorFilter.mode(
          Color.fromARGB((255 * strength).round().clamp(0, 255), 0, 0, 0),
          BlendMode.srcIn,
        )
        ..blendMode = BlendMode.dstOut,
    );
  }
}

/// 页面底（L0 裱绫）：纸色 + 固定不动的纸纹。包在 Scaffold.body 外层。
class XqPaperPage extends StatelessWidget {
  final Widget child;
  final Color? color;

  const XqPaperPage({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? t.backgroundColor,
        image: XqPaper.grain(t.paperFiber, strength: t.isDark ? 0.6 : 0.8),
      ),
      child: child,
    );
  }
}

/// 纹理覆盖层画笔：在天色之上铺一层纸纹（版画印在纸上，纸纹应透上来）
class XqGrainPainter extends CustomPainter {
  final ui.Image? image;
  final Color tint;

  XqGrainPainter({required this.image, required this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = XqPaper.shader(img)
        ..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }

  @override
  bool shouldRepaint(XqGrainPainter old) => old.image != image || old.tint != tint;
}

/// 手工纸的毛边：顶边按固定种子起伏，其余三边平直。
Path deckleTopPath(Size size, {int seed = 3, double amp = 1.8}) {
  final rng = math.Random(seed);
  final ph1 = rng.nextDouble() * math.pi * 2;
  final ph2 = rng.nextDouble() * math.pi * 2;
  final w = size.width;
  final path = Path()..moveTo(0, size.height);
  for (var x = 0.0; x <= w + 2; x += 2) {
    final y = amp +
        math.sin(x / w * math.pi * 6 + ph1) * amp * 0.45 +
        math.sin(x / w * math.pi * 31 + ph2) * amp * 0.3 +
        (rng.nextDouble() - 0.5) * amp * 1.1;
    path.lineTo(math.min(x, w), y.clamp(0.0, amp * 2.8));
  }
  path
    ..lineTo(w, size.height)
    ..close();
  return path;
}

class _DeckleClipper extends CustomClipper<Path> {
  final int seed;
  const _DeckleClipper(this.seed);

  @override
  Path getClip(Size size) => deckleTopPath(size, seed: seed);

  @override
  bool shouldReclip(_DeckleClipper old) => old.seed != seed;
}

class _DeckleShadowPainter extends CustomPainter {
  final int seed;
  final Color shadow;

  _DeckleShadowPainter(this.seed, this.shadow);

  @override
  void paint(Canvas canvas, Size size) {
    final path = deckleTopPath(size, seed: seed).shift(const Offset(0, -5));
    canvas.drawPath(
      path,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(_DeckleShadowPainter old) => old.seed != seed || old.shadow != shadow;
}

/// L2 叠上来的一张纸：毛边顶 + 纸纹 + 向上的一道影（全 App 唯一的投影）
class XqDeckleSheet extends StatelessWidget {
  final Widget child;
  final Color? color;
  final int seed;
  final EdgeInsetsGeometry padding;

  const XqDeckleSheet({
    super.key,
    required this.child,
    this.color,
    this.seed = 3,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    return CustomPaint(
      painter: _DeckleShadowPainter(
        seed,
        (t.isDark ? Colors.black : const Color(0xFF3B2F22)).withAlpha(t.isDark ? 90 : 40),
      ),
      child: ClipPath(
        clipper: _DeckleClipper(seed),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color ?? t.backgroundColor,
            image: XqPaper.grain(t.paperFiber, strength: t.isDark ? 0.6 : 0.8),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 颜料一抹：心情色不画正圆点，画成颜料碟里蘸出的一点——边缘不规则、边上积色、纸纹透出。
class XqPigmentDab extends StatelessWidget {
  final Color color;
  final double size;
  final int seed;

  const XqPigmentDab({super.key, required this.color, this.size = 26, this.seed = 1});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ui.Image?>(
      valueListenable: XqPaper.image,
      builder: (context, img, _) => CustomPaint(
        size: Size.square(size),
        painter: _DabPainter(color: color, seed: seed, image: img),
      ),
    );
  }
}

class _DabPainter extends CustomPainter {
  final Color color;
  final int seed;
  final ui.Image? image;

  _DabPainter({required this.color, required this.seed, required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed * 131 + 17);
    final c = size.center(Offset.zero);
    final r = size.width / 2 * 0.86;
    final harmonics = [
      for (var k = 2; k <= 6; k++)
        (k: k, amp: (0.07 / (k - 1)) * (0.6 + rng.nextDouble() * 0.8), ph: rng.nextDouble() * math.pi * 2),
    ];
    final tilt = rng.nextDouble() * math.pi;
    final path = Path();
    const n = 56;
    for (var i = 0; i <= n; i++) {
      final a = i / n * math.pi * 2;
      var rr = r;
      for (final h in harmonics) {
        rr += r * h.amp * math.sin(h.k * a + h.ph);
      }
      // 略扁，像笔肚压下去的一点
      final x = math.cos(a) * rr * 1.08, y = math.sin(a) * rr * 0.9;
      final p = c + Offset(x * math.cos(tilt) - y * math.sin(tilt), x * math.sin(tilt) + y * math.cos(tilt));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    final bounds = (Offset.zero & size).inflate(2);
    canvas.saveLayer(bounds, Paint());
    canvas.drawPath(path, Paint()..color = color.withAlpha(232));
    // 边上积色：颜料干时往边缘走
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.28)!.withAlpha(110)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );
    final img = image;
    if (img != null) {
      XqPaper.erode(canvas, bounds, img,
          strength: 0.75, scale: 0.42, shift: Offset(seed * 41.0, seed * 67.0));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DabPainter old) => old.color != color || old.seed != seed || old.image != image;
}
