import 'package:flutter/material.dart';

/// 按压缩放微交互：按下缩到 scale，松开回弹
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final VoidCallback? onTap;

  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.onTap,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _anim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 系统减弱动效：保留点击，去掉缩放
    if (MediaQuery.of(context).disableAnimations) {
      return GestureDetector(onTap: widget.onTap, child: widget.child);
    }
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.reverse(),
      onTapUp: (_) => _ctrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _anim, child: widget.child),
    );
  }
}
