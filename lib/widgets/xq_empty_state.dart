import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';

/// 空页点景：芥子园线稿（一枝寒枝 / 一叶孤舟 / 一片归帆）
enum XqMotif { branch, boat, sail }

/// 空状态：淡墨线稿一幅 + 一句事实 + 一句怎么开始。不用大图标，不用感叹号。
class XqEmptyState extends StatelessWidget {
  final XqMotif motif;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const XqEmptyState({
    super.key,
    this.motif = XqMotif.branch,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/motifs/${motif.name}.png',
              width: 132,
              color: t.ink.withAlpha(t.isDark ? 70 : 60),
              colorBlendMode: BlendMode.srcIn,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: XqTypography.headlineSmall.copyWith(color: t.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: t.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
