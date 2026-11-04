import 'package:flutter/material.dart';
import '../widgets/xq/xq_icons.dart';
import '../constants/app_info.dart';
import '../theme/xq_typography.dart';
import '../widgets/xq/xq_kit.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../stores/theme_state.dart';
import '../widgets/xq/xq_paper.dart';
import '../widgets/xq/xq_surface.dart';
import 'legal_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('关于拾晴日记'),
        backgroundColor: theme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: theme.textPrimary,
      ),
      body: XqPaperPage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _buildAppHeader(theme),
            const SizedBox(height: 8),
            // 缘起：一段话讲名字和这本笺谱想做的事
            XqSurface(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Text(
                '「拾晴」，是把晴天一片一片拾起来。\n'
                '天气每天都在变，心情也是。拾晴日记想做一本小小的笺谱：每天印一张笺，记下那天的天色、节气，和你写下的几句话。'
                '日子久了再翻回去，有阴天，也有晴天，都是你走过的日子。',
                style: TextStyle(
                  fontFamily: XqTypography.content,
                  fontFamilyFallback: XqTypography.contentFallback,
                  color: theme.textSecondary,
                  fontSize: 15,
                  height: 1.85,
                ),
              ),
            ),
            const SizedBox(height: 28),
            XqSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _row(theme, '隐私政策', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalPage(isPrivacy: true)))),
                  _rule(theme),
                  _row(theme, '用户协议', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalPage(isPrivacy: false)))),
                  _rule(theme),
                  _row(theme, '权限说明', () => _showPermissionsSheet(context, theme)),
                  _rule(theme),
                  _row(theme, '意见反馈', () => _showFeedbackSheet(context, theme)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: () => _launchUrl('https://beian.miit.gov.cn/'),
                child: Text('赣ICP备2026009414号-3A', style: TextStyle(color: theme.textTertiary, fontSize: 11.5)),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('© 2026 拾晴日记', style: TextStyle(color: theme.textTertiary, fontSize: 11.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule(ThemeState theme) => Container(height: 0.6, color: theme.borderColor);

  Widget _row(ThemeState theme, String title, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 15))),
            XqIcon(XqIcons.chevronRight, color: theme.frameColor, size: 16),
          ],
        ),
      ),
    );
  }

  // ── App 头部 ──
  Widget _buildAppHeader(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // 品牌印：与登录页同一方朱砂「拾」
          XqSeal(char: '拾', color: theme.sealColor, size: 60, style: XqSealStyle.bai),
          const SizedBox(height: 14),
          Text(
            '拾晴日记',
            style: XqTypography.displaySmall.copyWith(
              color: theme.textPrimary,
              fontSize: 24,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '记下每天的天气与心情',
            style: TextStyle(color: theme.textSecondary, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          Text(
            '版本 $appVersion',
            style: TextStyle(
              color: theme.gold,
              fontSize: 13,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ── 权限说明弹窗 ──
  static void _showPermissionsSheet(BuildContext context, ThemeState theme) {
    final permissions = [
      _PermissionItem(
        icon: XqIcons.pin,
        name: '位置信息',
        purpose: '获取当前城市天气和城迹足迹功能',
        required: true,
      ),
      _PermissionItem(
        icon: XqIcons.bell,
        name: '通知',
        purpose: '时光胶囊到期提醒',
        required: false,
      ),
      _PermissionItem(
        icon: XqIcons.wifi,
        name: '网络访问',
        purpose: '数据同步、天气获取、心情记录',
        required: true,
      ),
      _PermissionItem(
        icon: XqIcons.bell,
        name: '精确闹钟',
        purpose: '胶囊定时提醒（精确到分钟）',
        required: false,
      ),
      _PermissionItem(
        icon: XqIcons.folder,
        name: '本地存储',
        purpose: '心情卡片导出、缓存天气和城市数据',
        required: true,
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽条
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    XqIcon(XqIcons.key,
                        color: theme.accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '权限使用说明',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '只申请下面这些权限',
                  style: TextStyle(color: theme.textTertiary, fontSize: 12),
                ),
              ),

              // 权限列表
              ...permissions.map((p) => _buildPermissionTile(p, theme)),

              // 底部提示
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      XqIcon(XqIcons.info,
                          size: 14, color: theme.accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '可以随时在系统设置里关掉，对应的功能会用不了',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildPermissionTile(_PermissionItem p, ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.borderColor.withAlpha(60)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: p.required
                    ? theme.accentColor.withAlpha(15)
                    : theme.textTertiary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: XqIcon(
                p.icon,
                size: 17,
                color: p.required ? theme.accentColor : theme.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (p.required) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '必要',
                            style: TextStyle(
                              color: theme.accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.purpose,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showFeedbackSheet(BuildContext context, ThemeState theme) {
    final ctrl = TextEditingController();
    var sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽条
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: theme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 标题
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Row(
                      children: [
                        XqIcon(XqIcons.write,
                            color: theme.accentColor, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '意见反馈',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      '哪里不好用、想要什么功能，都可以写。',
                      style: TextStyle(color: theme.textTertiary, fontSize: 12),
                    ),
                  ),

                  // 输入框
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: ctrl,
                      maxLength: 1000,
                      maxLines: 5,
                      minLines: 3,
                      style: TextStyle(color: theme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '比如：心情页保存按钮不好找',
                        hintStyle: TextStyle(
                          color: theme.textTertiary.withAlpha(120),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: theme.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.borderColor.withAlpha(120)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.accentColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  // 提交按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: sending
                            ? null
                            : () async {
                                final text = ctrl.text.trim();
                                if (text.isEmpty) return;
                                setSheetState(() => sending = true);
                                try {
                                  await Api.sendFeedback(text);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('收到了，谢谢'),
                                        backgroundColor: theme.successColor,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                        margin: const EdgeInsets.fromLTRB(60, 0, 60, 16),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  setSheetState(() => sending = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: const Text('没发出去，等会儿再试'),
                                        backgroundColor: theme.errorColor,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                        margin: const EdgeInsets.fromLTRB(60, 0, 60, 16),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          foregroundColor: theme.textOnAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: sending
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: XqInkLoader( color: Colors.white),
                              )
                            : const Text('提交反馈', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _PermissionItem {
  final XqIcons icon;
  final String name;
  final String purpose;
  final bool required;

  const _PermissionItem({
    required this.icon,
    required this.name,
    required this.purpose,
    required this.required,
  });
}
