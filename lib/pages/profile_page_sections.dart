part of 'profile_page.dart';

extension _ProfilePageSections on _ProfilePageState {
  /// 名帖：宋体名字 + 一方小印（无头像时以名字首字作印，本屏唯一朱砂）
  Widget _profileHeader(ThemeState theme, AppState appState) {
    final name = appState.displayName.isNotEmpty ? appState.displayName : '未署名';
    final accountText = _phone.isEmpty ? '已登录' : _phone;
    final initial = name.characters.first;

    return XqSurface(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XqTypography.displayLarge.copyWith(
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  accountText,
                  style: TextStyle(
                    color: theme.textTertiary,
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    children: [
                      const TextSpan(text: '连续记录 '),
                      TextSpan(
                        text: '$_consecutive',
                        style: TextStyle(
                          color: theme.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const TextSpan(text: ' 天'),
                      const TextSpan(text: '   ·   '),
                      TextSpan(text: _checkedIn ? '今天已记' : '今天还没记'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            button: true,
            label: '更换头像',
            child: GestureDetector(
              onTap: _pickAvatar,
              child: _avatarPath != null
                  ? Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.borderColor, width: 0.8),
                      ),
                      child: ClipOval(
                        child: Image.file(File(_avatarPath!), fit: BoxFit.cover),
                      ),
                    )
                  : XqSeal(char: initial, color: theme.sealColor, size: 56),
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
        Padding(padding: const EdgeInsets.only(left: 50), child: Divider(height: 1, color: theme.borderColor)),
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
        Padding(padding: const EdgeInsets.only(left: 50), child: Divider(height: 1, color: theme.borderColor)),
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
        Padding(padding: const EdgeInsets.only(left: 50), child: Divider(height: 1, color: theme.borderColor)),
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
        Padding(padding: const EdgeInsets.only(left: 50), child: Divider(height: 1, color: theme.borderColor)),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.sunkenColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.textSecondary, size: 19),
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.textTertiary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.borderColor,
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
          const SizedBox(height: 10),
          _themeSelectorGrid(theme),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '再点一次已选中的主题，可以看它的由来',
                  style: TextStyle(
                    color: theme.textTertiary,
                    fontSize: 12,
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
                Icons.notifications_none_rounded,
                size: 20,
                color: theme.textSecondary,
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
                        fontSize: 15,
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
                                Icons.check,
                                color: colors[0],
                                size: 16,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _readableTextOn(colors[2]).withAlpha(180),
                            fontSize: 11,
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

  Widget _sectionTitle(String text, ThemeState theme, {String? subtitle}) =>
      XqSectionTitle(text, caption: subtitle);

  /// 分组卡片（L1）
  Widget _card(ThemeState theme, {required Widget child}) => XqSurface(
        padding: const EdgeInsets.fromLTRB(16, 6, 14, 6),
        child: child,
      );

  Widget _divider(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
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
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.sunkenColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.textSecondary, size: 19),
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
                        fontSize: 15,
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
                  fontSize: 13,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.borderColor,
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
