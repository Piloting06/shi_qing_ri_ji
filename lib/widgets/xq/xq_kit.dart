import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'xq_icons.dart';
import 'xq_paper.dart';

/// 素笺基础组件库。色值一律走 ThemeState/Theme，禁止硬编码。

/// 按钮：主（accent 底）/ 次（描边）/ 文字 / 危险 四型。
/// 高 48（主）/40；圆角 4；loading 保持宽度；禁用态清晰。
class XqButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final XqButtonType type;
  final double height;
  final bool loading;
  final dynamic icon; // XqIcons 或 Material XqIcons
  final bool expand; // 是否通栏

  const XqButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = XqButtonType.primary,
    this.height = 48,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final accent = t.colorScheme.primary;
    final onAccent = t.colorScheme.onPrimary;

    Color? bg;
    Color? fg;
    BorderSide side = BorderSide.none;
    switch (type) {
      case XqButtonType.primary:
        bg = accent;
        fg = onAccent;
      case XqButtonType.secondary:
        bg = Colors.transparent;
        fg = t.textTheme.bodyLarge?.color;
        side = BorderSide(color: t.colorScheme.outline, width: 1);
      case XqButtonType.text:
        bg = Colors.transparent;
        fg = accent;
      case XqButtonType.danger:
        bg = Colors.transparent;
        fg = t.colorScheme.error;
        side = BorderSide(color: t.colorScheme.error.withAlpha(120), width: 1);
    }

    final content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: XqInkLoader( color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                XqIcon(icon as XqIcons, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                  color: fg,
                ),
              ),
            ],
          );

    final btn = _XqPressable(
      onPressed: loading ? null : onPressed,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: height == 48 ? 28.0 : 20.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        ),
        child: content,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

enum XqButtonType { primary, secondary, text, danger }

/// 按压缩放（97%）+ 减弱动效跳过
class _XqPressable extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const _XqPressable({required this.onPressed, required this.child});

  @override
  State<_XqPressable> createState() => _XqPressableState();
}

class _XqPressableState extends State<_XqPressable>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final _anim = Tween(begin: 1.0, end: 0.98).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final reduced = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      onTapDown: disabled || reduced ? null : (_) => _ctrl.forward(),
      onTapCancel: disabled || reduced ? null : () => _ctrl.reverse(),
      onTapUp: disabled || reduced ? null : (_) => _ctrl.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(scale: _anim, child: widget.child),
    );
  }
}

/// 素笺标签：高 28，圆角 2，sunken 底；选中转 accent 染底。
class XqTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const XqTag({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.colorScheme.primary.withAlpha(24) : t.dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? t.colorScheme.primary : t.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

/// 印的两种刻法：朱文（字是红的，留边框）/ 白文（红底，字留白）
enum XqSealStyle { zhu, bai }

/// 印：刻刀不匀的边框 + 印泥斑驳（纸纹侵蚀）+ 微倾。支持 1 / 2（竖排）/ 4 字（右起两列）。
/// 印文用思源宋子集 600：印要有分量，展示字体太细。
class XqSeal extends StatelessWidget {
  final String char;
  final Color color;
  final double size;
  final XqSealStyle style;
  final double angle;

  const XqSeal({
    super.key,
    required this.char,
    required this.color,
    this.size = 30,
    this.style = XqSealStyle.zhu,
    this.angle = -0.05,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: char,
      excludeSemantics: true,
      child: ValueListenableBuilder<ui.Image?>(
        valueListenable: XqPaper.image,
        builder: (context, img, _) => CustomPaint(
          size: Size.square(size),
          painter: _SealPainter(char: char, color: color, style: style, angle: angle, image: img),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  final String char;
  final Color color;
  final XqSealStyle style;
  final double angle;
  final ui.Image? image;

  _SealPainter({
    required this.char,
    required this.color,
    required this.style,
    required this.angle,
    required this.image,
  });

  int get _seed => char.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rng = math.Random(_seed);
    final bounds = (Offset.zero & size).inflate(s * 0.08);
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(angle);
    canvas.translate(-s / 2, -s / 2);
    canvas.saveLayer(bounds, Paint());

    final inset = s * 0.05;
    final frame = _roughRect(Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2), rng, s * 0.014);
    if (style == XqSealStyle.bai) {
      canvas.drawPath(frame, Paint()..color = color);
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstOut);
      _paintChars(canvas, s, const Color(0xFF000000));
      canvas.restore();
    } else {
      canvas.drawPath(
        frame,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..strokeJoin = StrokeJoin.round,
      );
      _paintChars(canvas, s, color);
    }

    // 边上的崩口：刻石用久了的缺损
    final nick = Paint()..blendMode = BlendMode.dstOut;
    for (var i = 0; i < 3; i++) {
      final t = rng.nextDouble();
      final side = rng.nextInt(4);
      final p = switch (side) {
        0 => Offset(inset + t * (s - inset * 2), inset),
        1 => Offset(s - inset, inset + t * (s - inset * 2)),
        2 => Offset(inset + t * (s - inset * 2), s - inset),
        _ => Offset(inset, inset + t * (s - inset * 2)),
      };
      canvas.drawCircle(p, s * (0.02 + rng.nextDouble() * 0.025), nick);
    }

    final img = image;
    if (img != null) {
      XqPaper.erode(canvas, bounds, img,
          strength: 0.8, scale: 0.36, shift: Offset((_seed % 400).toDouble(), (_seed ~/ 7 % 400).toDouble()));
    }
    canvas.restore();
    canvas.restore();
  }

  /// 四边逐段抖动的方框：刻刀走得不匀
  Path _roughRect(Rect r, math.Random rng, double j) {
    final pts = <Offset>[];
    const seg = 6;
    double jit() => (rng.nextDouble() - 0.5) * 2 * j;
    for (var i = 0; i < seg; i++) {
      pts.add(Offset(r.left + r.width * i / seg, r.top + jit()));
    }
    for (var i = 0; i < seg; i++) {
      pts.add(Offset(r.right + jit(), r.top + r.height * i / seg));
    }
    for (var i = 0; i < seg; i++) {
      pts.add(Offset(r.right - r.width * i / seg, r.bottom + jit()));
    }
    for (var i = 0; i < seg; i++) {
      pts.add(Offset(r.left + jit(), r.bottom - r.height * i / seg));
    }
    return Path()..addPolygon(pts, true);
  }

  void _paintChars(Canvas canvas, double s, Color c) {
    final chars = char.characters.toList();
    final n = chars.length >= 4 ? 4 : chars.length.clamp(1, 3);
    final fontSize = switch (n) { 1 => s * 0.58, 2 => s * 0.4, 3 => s * 0.28, _ => s * 0.36 };
    // 每格中心：单字居中；两字竖排；四字右起两列（先右列上下，再左列上下）
    final cells = switch (n) {
      1 => [Offset(s / 2, s / 2)],
      2 => [Offset(s / 2, s * 0.3), Offset(s / 2, s * 0.7)],
      3 => [Offset(s / 2, s * 0.24), Offset(s / 2, s * 0.5), Offset(s / 2, s * 0.76)],
      _ => [Offset(s * 0.7, s * 0.3), Offset(s * 0.7, s * 0.7), Offset(s * 0.3, s * 0.3), Offset(s * 0.3, s * 0.7)],
    };
    for (var i = 0; i < n; i++) {
      for (final stroke in [false, true]) {
        final tp = TextPainter(
          text: TextSpan(
            text: chars[i],
            style: TextStyle(
              fontFamily: 'SerifSC',
              fontFamilyFallback: const ['Songti SC'],
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.0,
              foreground: Paint()
                ..color = c
                ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
                ..strokeWidth = s * 0.016,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, cells[i] - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.char != char || old.color != color || old.style != style || old.angle != angle || old.image != image;
}

/// 宋体页头：标题 + 可选说明。
class XqPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const XqPageHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: t.textTheme.bodyLarge?.color,
            fontSize: 21,
            fontWeight: FontWeight.w400,
            fontFamily: 'Display',
            fontFamilyFallback: ['SerifSC', 'Songti SC'],
            height: 1.45,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(color: t.textTheme.bodySmall?.color, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// 素笺卡片：surface 底 + 1px 细线，圆角 8，无阴影。
class XqCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const XqCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.dividerColor, width: 0.6),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: card,
    );
  }
}

/// 三点墨：取代系统转圈。三粒墨点依次由淡转浓，循环 900ms；减弱动效时静止。
class XqInkLoader extends StatefulWidget {
  final Color? color;
  final double dot;

  const XqInkLoader({super.key, this.color, this.dot = 4.5});

  @override
  State<XqInkLoader> createState() => _XqInkLoaderState();
}

class _XqInkLoaderState extends State<XqInkLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '加载中',
      child: LayoutBuilder(
        builder: (context, c) {
          final d = c.hasBoundedWidth ? math.min(widget.dot, c.maxWidth / 5) : widget.dot;
          return Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) SizedBox(width: d * 0.8),
                    Opacity(
                      opacity: 0.25 + 0.75 * (0.5 + 0.5 * math.cos((_c.value - i / 3) * 2 * math.pi)),
                      child: Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 下拉刷新：手势沿用系统（noSpinner），指示换成顶部一行三点墨。
class XqRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;

  const XqRefresh({super.key, required this.onRefresh, required this.child, this.edgeOffset = 0});

  @override
  State<XqRefresh> createState() => _XqRefreshState();
}

class _XqRefreshState extends State<XqRefresh> {
  RefreshIndicatorStatus? _status;

  @override
  Widget build(BuildContext context) {
    final show = switch (_status) {
      RefreshIndicatorStatus.armed || RefreshIndicatorStatus.snap || RefreshIndicatorStatus.refresh => true,
      _ => false,
    };
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: (s) {
            if (mounted && s != _status) setState(() => _status = s);
          },
          child: widget.child,
        ),
        Positioned(
          top: widget.edgeOffset + 14,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: show ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: const SizedBox(height: 12, child: XqInkLoader()),
            ),
          ),
        ),
      ],
    );
  }
}
