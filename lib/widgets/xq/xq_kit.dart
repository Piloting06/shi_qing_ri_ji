import 'package:flutter/material.dart';
import 'xq_icons.dart';

/// 素笺基础组件库。色值一律走 ThemeState/Theme，禁止硬编码。

/// 按钮：主（accent 底）/ 次（描边）/ 文字 / 危险 四型。
/// 高 48（主）/40；圆角 4；loading 保持宽度；禁用态清晰。
class XqButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final XqButtonType type;
  final double height;
  final bool loading;
  final dynamic icon; // XqIcons 或 Material IconData
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
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                if (icon is XqIcons)
                  XqIcon(icon as XqIcons, size: 18, color: fg)
                else
                  Icon(icon as IconData?, size: 18, color: fg),
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

/// 方形小印：朱砂或心情釉色，方形、微倾、单字。
class XqSeal extends StatelessWidget {
  final String char;
  final Color color;
  final double size;

  const XqSeal({super.key, required this.char, required this.color, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.4),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Text(
          char,
          style: TextStyle(
            color: color,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w600,
            fontFamily: 'SerifSC',
            fontFamilyFallback: ['Songti SC'],
          ),
        ),
      ),
    );
  }
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
            fontSize: 20,
            fontWeight: FontWeight.w500,
            fontFamily: 'SerifSC',
            fontFamilyFallback: ['Noto Serif SC', 'Songti SC'],
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
