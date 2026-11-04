import 'package:flutter/material.dart';
import 'xq_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../stores/theme_state.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import 'xq_paper.dart';

/// 表面体系（DESIGN.md「层级」，P9 笺谱 · 装裱）：
/// L0 裱绫（页面底，偏深）→ L1 笺（XqSurface：更亮的纸 + 一圈细墨线 + 纸纹）→ L2 毛边叠纸（XqDeckleSheet）。
/// 笺里不再套笺；笺内的次级块用凹陷底（sunken）。

/// L1 笺。可点时带按压缩放与轻触感。
class XqSurface extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  const XqSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.radius = XqDecorations.radiusCard,
    this.color,
  });

  @override
  State<XqSurface> createState() => _XqSurfaceState();
}

class _XqSurfaceState extends State<XqSurface> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final card = Container(
      decoration: XqDecorations.surface(
        widget.color ?? t.cardColor,
        dark: t.isDark,
        edge: t.frameColor,
        radius: widget.radius,
        grain: XqPaper.grain(t.paperFiber, strength: t.isDark ? 0.6 : 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
    if (widget.onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down && !reduce ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuart,
        child: card,
      ),
    );
  }
}

/// 区块标题：展示字体题 + 一道乌丝栏细线引到右侧（可选说明/右侧操作）。放在笺外，不进笺。
class XqSectionTitle extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? trailing;

  const XqSectionTitle(this.title, {super.key, this.caption, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: XqTypography.headlineSmall.copyWith(color: t.textPrimary, fontSize: 18, letterSpacing: 1)),
          if (caption != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textTertiary, fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(child: Container(height: 0.6, color: t.frameColor)),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// 分组：标题在外，一张卡片里装若干行，行间内缩细线（iOS 分组列表的结构）。
class XqGroup extends StatelessWidget {
  final String? title;
  final String? caption;
  final List<Widget> children;
  final bool insetDivider; // 有前置图标时细线从文字处开始

  const XqGroup({
    super.key,
    this.title,
    this.caption,
    required this.children,
    this.insetDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: insetDivider ? 52 : 18),
          child: Container(height: 0.6, color: t.borderColor),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) XqSectionTitle(title!, caption: caption),
        XqSurface(
          padding: EdgeInsets.zero,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ],
    );
  }
}

/// 列表行（乌丝栏目录）：前置线描小图标（不加底块）· 标题/说明 · 右侧值或细箭头。高 ≥ 60。
class XqRow extends StatelessWidget {
  final XqIcons? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;

  const XqRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    final titleColor = destructive ? t.errorColor : t.textPrimary;
    final lead = leading ??
        (icon == null
            ? null
            : SizedBox(
                width: 22,
                child: XqIcon(icon!, size: 20, color: destructive ? t.errorColor : t.textSecondary),
              ));
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: TextStyle(color: titleColor, fontSize: 15.5)),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.textTertiary, fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    value!,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 14,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                if (onTap != null && chevron) ...[
                  const SizedBox(width: 6),
                  XqIcon(XqIcons.chevronRight, size: 18, color: t.textTertiary.withAlpha(120)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
