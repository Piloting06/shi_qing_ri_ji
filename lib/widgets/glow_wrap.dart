import 'package:flutter/material.dart';

/// 素笺化后的手势包装：保留原公共 API（accentColor/radius/onTap/child），
/// 光效层已按规范移除——点击反馈交给调用方的 Ink/Pressable 层。
class GlowWrap extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final double radius;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const GlowWrap({
    super.key,
    required this.child,
    required this.accentColor,
    this.radius = 40,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
