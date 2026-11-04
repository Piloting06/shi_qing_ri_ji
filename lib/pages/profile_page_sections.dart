part of 'profile_page.dart';

extension _ProfilePageSections on _ProfilePageState {
  Widget _profileHeader(ThemeState theme, AppState appState) {
    final name = appState.displayName.isNotEmpty ? appState.displayName : '用户';
    final accountText = _phone.isEmpty ? '账号信息已同步' : _phone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: XqDecorations.heroCard(
        theme.cardColor.withAlpha(theme.isDark ? 238 : 248),
        theme.cardElevated.withAlpha(theme.isDark ? 210 : 236),
        theme.borderColor,
        dark: theme.isDark,
        glow: theme.accentColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.accentColor.withAlpha(46),
                            theme.gold.withAlpha(theme.isDark ? 34 : 46),
                          ],
                        ),
                        border: Border.all(
                          color: theme.accentColor.withAlpha(100),
                          width: 1.4,
                        ),
                        boxShadow: XqDecorations.shadowSubtle(
                          dark: theme.isDark,
                        ),
                      ),
                      child: _avatarPath != null
                          ? ClipOval(
                              child: Image.file(
                                File(_avatarPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.person_outline_rounded,
                              size: 34,
                              color: theme.accentColor,
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.cardColor, width: 2),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: theme.textOnAccent,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: XqTypography.headlineMedium.copyWith(
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      accountText,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _profilePill(
                          theme,
                          Icons.local_fire_department_outlined,
                          '连续 $_consecutive 天',
                        ),
                        _profilePill(
                          theme,
                          _checkedIn
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          _checkedIn ? '今日已记' : '今日未记',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profilePill(ThemeState theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.accentColor.withAlpha(55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.accentColor, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: theme.accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordsGroup(ThemeState theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('记录概览', theme),
        const SizedBox(height: 8),
        _listTile(
          theme,
          icon: _checkedIn
              ? Icons.check_circle_outline_rounded
              : Icons.local_fire_department_outlined,
          iconColor: _checkedIn ? theme.successColor : theme.accentColor,
          title: _checkedIn ? '今日已记录' : '今天还没记',
          subtitle: _checkedIn
              ? '连续 $_consecutive 天'
              : (_checkingIn ? '正在记录' : '轻点签到'),
          onTap: (_checkedIn || _checkingIn) ? null : _doCheckin,
        ),
        Divider(height: 1, color: theme.borderColor.withAlpha(80)),
        _listTile(
          theme,
          icon: Icons.style_outlined,
          iconColor: theme.gold,
          title: '卡片册',
          subtitle: '你做过的所有心情卡片',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CardAlbumPage()),
            );
          },
        ),
        Divider(height: 1, color: theme.borderColor.withAlpha(80)),
        _listTile(
          theme,
          icon: Icons.spa_outlined,
          iconColor: theme.accentColor,
          title: '素笺',
          subtitle: '写一篇故事，或让节气替你起个头',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StoryListPage()),
            );
          },
        ),
        Divider(height: 1, color: theme.borderColor.withAlpha(80)),
        _listTile(
          theme,
          icon: Icons.hourglass_empty_rounded,
          iconColor: theme.accentColor,
          title: '时光胶囊',
          subtitle: _capsuleNotify ? '提醒已开启' : '提醒未开启',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CapsulePage()),
          ),
        ),
        Divider(height: 1, color: theme.borderColor.withAlpha(80)),
        _listTile(
          theme,
          icon: Icons.people_outline_rounded,
          iconColor: theme.accentColor,
          title: '好友心情',
          subtitle: '看看朋友近况',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FriendsPage()),
          ),
        ),
      ],
    );
  }

  Widget _listTile(
    ThemeState theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileSettingsGroup(ThemeState theme, AppState appState) {
    return _card(
      theme,
      child: Column(
        children: [
          _infoRow(
            theme,
            icon: Icons.badge_outlined,
            title: '昵称',
            subtitle: appState.displayName.isNotEmpty
                ? appState.displayName
                : '点击设置你的日记署名',
            trailing: '修改',
            onTap: () => _showNicknameDialog(theme, appState),
          ),
          _divider(theme),
          _infoRow(
            theme,
            icon: Icons.email_outlined,
            title: _boundEmail.isEmpty ? '绑定邮箱' : '邮箱',
            subtitle: _boundEmail.isEmpty ? '绑定后可用邮箱登录' : _boundEmail,
            trailing: _boundEmail.isEmpty ? '绑定' : '更换',
            onTap: () => _showEmailSheet(theme),
          ),
        ],
      ),
    );
  }

  Widget _appearanceGroup(ThemeState theme) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _themeSelectorGrid(theme),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: theme.textTertiary.withAlpha(160),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '点击已选中的主题，可以查看它的创作故事',
                  style: TextStyle(
                    color: theme.textTertiary.withAlpha(170),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: theme.borderColor.withAlpha(60), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: theme.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '胶囊提醒',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '到期时通过通知提醒我',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GlowSwitch(
                value: _capsuleNotify,
                onChanged: (v) async {
                  if (v) {
                    // 先检查是否已有权限
                    final alreadyGranted = await NotificationService.areSystemNotificationsEnabled();
                    if (alreadyGranted) {
                      _setCapsuleNotify(true);
                      return;
                    }
                    // 没有权限，请求系统弹窗
                    final granted = await NotificationService.requestPermissionIfNeeded();
                    if (!mounted) return;
                    if (!granted) {
                      // 被拒绝，提示去设置开启
                      if (mounted) {
                        XqToast.info(context, '需要通知权限才能提醒你，去设置里打开吧～');
                      }
                      return;
                    }
                  }
                  _setCapsuleNotify(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: theme.borderColor.withAlpha(60), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: theme.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '动感光效',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '胶囊导航和卡片的彩色光效',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GlowSwitch(
                value: context.watch<AppState>().animActive,
                onChanged: (v) => context.read<AppState>().setAnimActive(v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeSelectorGrid(ThemeState theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ThemeState.themeNames.entries.map((entry) {
            final active = theme.themeMode == entry.key;
            final colors = ThemeState.themeColors[entry.key]!;
            final desc = _themeSceneDesc(entry.key);
            return SizedBox(
              width: width,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
                  onTap: () {
                    if (active) {
                      _showThemeDetail(entry.key, entry.value, colors, desc);
                    } else {
                      theme.setTheme(entry.key);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    height: 78,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
                      color: colors[2],
                      border: Border.all(
                        color: active
                            ? colors[0]
                            : theme.borderColor.withAlpha(100),
                        width: active ? 1.6 : 0.7,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: colors[0].withAlpha(32),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...colors
                                .take(3)
                                .map(
                                  (c) => Container(
                                    width: 13,
                                    height: 13,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c,
                                      border: Border.all(
                                        color: Colors.white.withAlpha(140),
                                        width: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                            const Spacer(),
                            if (active)
                              Icon(
                                Icons.check_circle_rounded,
                                color: colors[0],
                                size: 17,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active
                                ? colors[0]
                                : _readableTextOn(colors[2]),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _readableTextOn(colors[2]).withAlpha(165),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _securityGroup(ThemeState theme) {
    return _card(
      theme,
      child: _infoRow(
        theme,
        icon: Icons.lock_outline_rounded,
        title: '修改密码',
        subtitle: '更改当前登录密码',
        trailing: '修改',
        onTap: () => _showPasswordSheet(theme),
      ),
    );
  }

  Widget _aboutGroup(ThemeState theme) {
    return _card(
      theme,
      child: Column(
        children: [
          _infoRow(
            theme,
            icon: Icons.info_outline_rounded,
            title: '关于拾晴日记',
            subtitle: '版本、合规、开源许可',
            trailing: '查看',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          _divider(theme),
          _infoRow(
            theme,
            icon: Icons.description_outlined,
            title: '隐私政策',
            subtitle: '查看数据和隐私说明',
            trailing: '查看',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalPage(isPrivacy: true),
              ),
            ),
          ),
          _divider(theme),
          _infoRow(
            theme,
            icon: Icons.article_outlined,
            title: '用户协议',
            subtitle: '查看使用约定',
            trailing: '查看',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalPage(isPrivacy: false),
              ),
            ),
          ),
          _divider(theme),
          _infoRow(
            theme,
            icon: Icons.chat_bubble_outline_rounded,
            title: '加入交流群',
            subtitle: '和更多用户一起聊聊',
            trailing: '加入',
            onTap: _openQqGroup,
          ),
        ],
      ),
    );
  }

  Future<void> _openQqGroup() async {
    final url = Uri.parse('https://qm.qq.com/q/EKUVPDQV8Y');
    try {
      final can = await canLaunchUrl(url);
      if (!mounted) return;
      if (can) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先安装 QQ')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('跳转失败，请稍后重试')));
    }
  }

  // ── Reusable components ──

  Widget _sectionTitle(String text, ThemeState theme, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(color: theme.textTertiary, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _card(ThemeState theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: XqDecorations.actionCard(
        theme.cardColor.withAlpha(theme.isDark ? 224 : 245),
        theme.borderColor,
        dark: theme.isDark,
        accent: theme.accentColor,
      ),
      child: child,
    );
  }

  Widget _divider(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: theme.borderColor, height: 1),
    );
  }

  Widget _infoRow(
    ThemeState theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                child: Icon(icon, color: theme.accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailing,
                style: TextStyle(
                  color: onTap == null ? theme.textTertiary : theme.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.accentColor.withAlpha(150),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
