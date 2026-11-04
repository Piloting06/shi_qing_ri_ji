import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          // ── App 头部 ──
          _buildAppHeader(theme),
          const SizedBox(height: 28),

          // ── 项目信息 ──
          _sectionTitle('项目信息', theme),
          const SizedBox(height: 10),
          _card(theme, children: [
            _infoRow(
              theme,
              icon: Icons.code_rounded,
              title: 'GitHub 仓库',
              subtitle: 'Piloting06/shi_qing_ri_ji',
              onTap: () => _launchUrl('https://github.com/Piloting06/shi_qing_ri_ji'),
            ),
            _divider(theme),
            _infoRow(
              theme,
              icon: Icons.balance_rounded,
              title: '开源许可',
              subtitle: 'MIT License',
              onTap: () => _showLicenseDialog(context, theme),
            ),
          ]),
          const SizedBox(height: 22),

          // ── 合规信息 ──
          _sectionTitle('合规信息', theme, subtitle: '符合国家标准与法规要求'),
          const SizedBox(height: 10),
          _card(theme, children: [
            _infoRow(
              theme,
              icon: Icons.verified_outlined,
              title: 'ICP 备案号',
              subtitle: '赣ICP备2026009414号-3A',
              onTap: () => _launchUrl('https://beian.miit.gov.cn/'),
            ),
            _divider(theme),
            _infoRow(
              theme,
              icon: Icons.shield_outlined,
              title: '隐私政策',
              subtitle: '数据收集、存储与使用说明',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalPage(isPrivacy: true)),
              ),
            ),
            _divider(theme),
            _infoRow(
              theme,
              icon: Icons.article_outlined,
              title: '用户协议',
              subtitle: '服务条款与使用约定',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalPage(isPrivacy: false)),
              ),
            ),
            _divider(theme),
            _infoRow(
              theme,
              icon: Icons.key_outlined,
              title: '权限说明',
              subtitle: '查看应用所使用的系统权限',
              onTap: () => _showPermissionsSheet(context, theme),
            ),
            _divider(theme),
            _infoRow(
              theme,
              icon: Icons.gavel_rounded,
              title: '国标合规',
              subtitle: 'GB/T 35273 · GB/T 41391 · GB/T 42574',
              onTap: () => _showComplianceSheet(context, theme),
            ),
          ]),
          const SizedBox(height: 22),

          // ── 联系与反馈 ──
          _sectionTitle('联系与反馈', theme),
          const SizedBox(height: 10),
          _card(theme, children: [
            _infoRow(
              theme,
              icon: Icons.mail_outline_rounded,
              title: '意见反馈',
              subtitle: '告诉我们你的想法和建议',
              onTap: () => _showFeedbackSheet(context, theme),
            ),
          ]),
          const SizedBox(height: 22),

          // ── 技术信息 ──
          _sectionTitle('技术信息', theme),
          const SizedBox(height: 10),
          _buildTechInfo(theme),
          const SizedBox(height: 32),

          // ── 底部版权 ──
          Center(
            child: Text(
              '© 2026 拾晴日记',
              style: TextStyle(color: theme.textTertiary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '记录天气，也记录你',
              style: TextStyle(
                color: theme.textTertiary.withAlpha(120),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App 头部 ──
  Widget _buildAppHeader(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // App 图标
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.accentColor.withAlpha(200),
                  theme.accentColor.withAlpha(140),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withAlpha(50),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '拾晴日记',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '记录天气，也记录你',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.accentColor.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'v2.6.0',
              style: TextStyle(
                color: theme.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 标题 ──
  Widget _sectionTitle(String text, ThemeState theme, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: theme.textTertiary, fontSize: 11),
          ),
        ],
      ],
    );
  }

  // ── 卡片容器 ──
  Widget _card(ThemeState theme, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: XqDecorations.actionCard(
        theme.cardColor.withAlpha(theme.isDark ? 224 : 245),
        theme.borderColor,
        dark: theme.isDark,
        accent: theme.accentColor,
      ),
      child: Column(children: children),
    );
  }

  // ── 行组件 ──
  Widget _infoRow(
    ThemeState theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.accentColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: theme.accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    color: theme.textTertiary.withAlpha(120), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(color: theme.borderColor.withAlpha(60), height: 1),
    );
  }

  // ── 技术信息 ──
  Widget _buildTechInfo(ThemeState theme) {
    final items = [
      ['框架', 'Flutter 3.38 / Dart 3.10'],
      ['平台', 'Android arm64'],
      ['后端', 'Node.js / Express / SQLite'],
      ['域名', 'xqrj.glxgo.xin (HTTPS)'],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: XqDecorations.actionCard(
        theme.cardColor.withAlpha(theme.isDark ? 224 : 245),
        theme.borderColor,
        dark: theme.isDark,
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    item[0],
                    style: TextStyle(
                      color: theme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item[1],
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 权限说明弹窗 ──
  static void _showPermissionsSheet(BuildContext context, ThemeState theme) {
    final permissions = [
      _PermissionItem(
        icon: Icons.location_on_outlined,
        name: '位置信息',
        code: 'ACCESS_FINE_LOCATION',
        purpose: '获取当前城市天气和城迹足迹功能',
        required: true,
      ),
      _PermissionItem(
        icon: Icons.notifications_outlined,
        name: '通知',
        code: 'POST_NOTIFICATIONS',
        purpose: '时光胶囊到期提醒',
        required: false,
      ),
      _PermissionItem(
        icon: Icons.wifi_outlined,
        name: '网络访问',
        code: 'INTERNET',
        purpose: '数据同步、天气获取、心情记录',
        required: true,
      ),
      _PermissionItem(
        icon: Icons.alarm_outlined,
        name: '精确闹钟',
        code: 'SCHEDULE_EXACT_ALARM',
        purpose: '胶囊定时提醒（精确到分钟）',
        required: false,
      ),
      _PermissionItem(
        icon: Icons.storage_outlined,
        name: '本地存储',
        code: 'READ/WRITE_STORAGE',
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
                    Icon(Icons.key_outlined,
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
                  '拾晴日记遵循最小必要原则，仅申请以下权限',
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
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: theme.accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '权限可在系统设置中随时关闭，但可能影响部分功能',
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
              child: Icon(
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
                  const SizedBox(height: 2),
                  Text(
                    p.code,
                    style: TextStyle(
                      color: theme.textTertiary,
                      fontSize: 10,
                      fontFamily: 'monospace',
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

  // ── 开源许可弹窗 ──
  static void _showLicenseDialog(BuildContext context, ThemeState theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        backgroundColor: theme.cardColor,
        title: Row(
          children: [
            Icon(Icons.balance_rounded, color: theme.accentColor, size: 20),
            const SizedBox(width: 8),
            const Text('MIT License'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'MIT License\n\n'
            'Copyright (c) 2026 拾晴日记\n\n'
            'Permission is hereby granted, free of charge, to any person '
            'obtaining a copy of this software and associated documentation '
            'files (the "Software"), to deal in the Software without '
            'restriction, including without limitation the rights to use, '
            'copy, modify, merge, publish, distribute, sublicense, and/or '
            'sell copies of the Software, and to permit persons to whom the '
            'Software is furnished to do so, subject to the following '
            'conditions:\n\n'
            'The above copyright notice and this permission notice shall be '
            'included in all copies or substantial portions of the Software.\n\n'
            'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, '
            'EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES '
            'OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND '
            'NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT '
            'HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, '
            'WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING '
            'FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR '
            'OTHER DEALINGS IN THE SOFTWARE.',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('关闭', style: TextStyle(color: theme.accentColor)),
          ),
        ],
      ),
    );
  }

  // ── 国标合规弹窗 ──
  static void _showComplianceSheet(BuildContext context, ThemeState theme) {
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.gavel_rounded,
                        color: theme.accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '国标合规声明',
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  '拾晴日记遵循以下国家标准与法规',
                  style: TextStyle(color: theme.textTertiary, fontSize: 12),
                ),
              ),
              _buildComplianceTile(
                theme,
                standard: 'GB/T 35273-2020',
                name: '个人信息安全规范',
                status: '已达标',
                detail: '提供完整的隐私政策，明确数据收集目的与范围',
              ),
              _buildComplianceTile(
                theme,
                standard: 'GB/T 41391-2022',
                name: 'APP收集个人信息基本要求',
                status: '已达标',
                detail: '仅收集手机号和心情数据，遵循最小必要原则',
              ),
              _buildComplianceTile(
                theme,
                standard: 'GB/T 42574-2023',
                name: '告知和同意的实施指南',
                status: '已达标',
                detail: '注册时展示用户协议与隐私政策，获得明确同意',
              ),
              _buildComplianceTile(
                theme,
                standard: 'ICP备案',
                name: '互联网信息服务备案',
                status: '已备案',
                detail: '赣ICP备2026009414号-3A',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: theme.borderColor),
                      ),
                    ),
                    child: const Text('关闭'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildComplianceTile(
    ThemeState theme, {
    required String standard,
    required String name,
    required String status,
    required String detail,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.borderColor.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    standard,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.successColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: theme.successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                color: theme.textTertiary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 意见反馈弹窗 ──
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
                        Icon(Icons.edit_note_rounded,
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
                      '写下你的想法，我们会认真阅读每一条反馈',
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
                        hintText: '例如：希望增加某某功能、某个页面不太方便...',
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
                                        content: const Text('谢谢你愿意告诉我们！每一条都会好好看'),
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
                                        content: const Text('没发出去，等一下再试试？'),
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
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
  final IconData icon;
  final String name;
  final String code;
  final String purpose;
  final bool required;

  const _PermissionItem({
    required this.icon,
    required this.name,
    required this.code,
    required this.purpose,
    required this.required,
  });
}
