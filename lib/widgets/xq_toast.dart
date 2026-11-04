import 'package:flutter/material.dart';
import 'xq/xq_icons.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';

/// 轻提示：一张小纸条从底部浮起（笺色 + 细墨框），不用彩色大底。
/// 成功前置一个勾、失败前置一个提醒，颜色只落在小图标上。
class XqToast {
  static void success(BuildContext context, String msg) =>
      _show(context, msg, icon: XqIcons.check, tone: (t) => t.successColor);

  static void error(BuildContext context, String msg) =>
      _show(context, msg, icon: XqIcons.alert, tone: (t) => t.errorColor, seconds: 3);

  static void info(BuildContext context, String msg) => _show(context, msg);

  static void _show(
    BuildContext context,
    String msg, {
    XqIcons? icon,
    Color Function(ThemeState)? tone,
    int seconds = 2,
  }) {
    final t = context.read<ThemeState>();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              XqIcon(icon, color: tone?.call(t) ?? t.textSecondary, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(msg, style: TextStyle(color: t.textPrimary, fontSize: 14, height: 1.4)),
            ),
          ],
        ),
        backgroundColor: t.cardElevated,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: t.frameColor, width: 0.6),
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        duration: Duration(seconds: seconds),
      ),
    );
  }
}
