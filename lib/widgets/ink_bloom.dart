import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 墨迹晕开：全产品唯一的仪式动效，用于时光胶囊开封时刻。
/// 一团墨在纸上晕开（主体 + 数枚飞沫），随后自动退场。
/// 规范约束：仅此一处使用；遵循系统减弱动效设置（直接跳过）。
class InkBloom {
  InkBloom._();

  /// 播放一次墨迹晕开；减弱动效时直接返回（无动画）。
  static Future<void> play(
    BuildContext context, {
    required Color ink,
    bool reducedMotion = false,
  }) async {
    if (reducedMotion) return;
    await Navigator.of(context, rootNavigator: true).push(_InkBloomRoute(ink));
  }
}

class _InkBloomRoute extends PopupRoute<void> {
  final Color ink;
  _InkBloomRoute(this.ink);

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => '墨迹晕开';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 1100);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return InkBloomView(ink: ink);
  }
}

class InkBloomView extends StatefulWidget {
  final Color ink;

  const InkBloomView({super.key, required this.ink});

  @override
  State<InkBloomView> createState() => _InkBloomViewState();
}

class _InkBloomViewState extends State<InkBloomView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _ctrl.forward().whenComplete(() {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          // 后段整体淡出
          final fade = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25);
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _InkBloomPainter(ink: widget.ink, t: t),
            ),
          );
        },
      ),
    );
  }
}

class _InkBloomPainter extends CustomPainter {
  final Color ink;
  final double t; // 0..1
  _InkBloomPainter({required this.ink, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.42;
    // 主体墨团：四层同心近似"洇纸"边缘
    for (int i = 3; i >= 0; i--) {
      final r =
          maxR * (1 - i * 0.16) * _easeOut((t * 1.08).clamp(0.0, 1.0));
      canvas.drawCircle(
        center,
        r,
        Paint()..color = ink.withAlpha((90 - i * 22).clamp(10, 90)),
      );
    }
    // 飞沫：8 枚环绕，比主体晚启动
    final rng = math.Random(7);
    final dropletT =
        _easeOut(((t - 0.15) / 0.85).clamp(0.0, 1.0));
    for (int i = 0; i < 8; i++) {
      final angle = i * 0.785 + rng.nextDouble() * 0.5;
      final dist = maxR * (0.75 + rng.nextDouble() * 0.55) * dropletT;
      final r = (4 + rng.nextDouble() * 9) * dropletT;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * dist, math.sin(angle) * dist),
        r,
        Paint()..color = ink.withAlpha((52 * (1 - t * 0.4)).round()),
      );
    }
  }

  static double _easeOut(double x) => 1 - math.pow(1 - x, 3).toDouble();

  @override
  bool shouldRepaint(covariant _InkBloomPainter old) => old.t != t;
}
