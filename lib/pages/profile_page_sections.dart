part of 'profile_page.dart';

/// 「我」页像一本手账的扉页：名帖 → 这个月 → 我的东西 → 纸 → 设置 → 牌记。
/// 设置行不带图标（不是系统设置页），只有字、值和一道乌丝栏。
extension _ProfilePageSections on _ProfilePageState {
  // ── 名帖 ──

  Widget _profileHeader(ThemeState theme, AppState appState) {
    final name = appState.displayName.isNotEmpty ? appState.displayName : '未署名';
    final accountText = _phone.isEmpty ? (_boundEmail.isEmpty ? '已登录' : _boundEmail) : _phone;
    final initial = name.characters.first;
    final num = TextStyle(
      color: theme.gold,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return XqSurface(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: XqTypography.displayLarge.copyWith(color: theme.textPrimary, fontSize: 30),
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
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: theme.frameColor, width: 0.6),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Image.file(File(_avatarPath!), fit: BoxFit.cover),
                          ),
                        )
                      : XqSeal(char: initial, color: theme.sealColor, size: 56, style: XqSealStyle.bai),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 0.6, color: theme.borderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    children: [
                      const TextSpan(text: '连续 '),
                      TextSpan(text: '$_consecutive', style: num),
                      const TextSpan(text: ' 天   共记 '),
                      TextSpan(text: '$_totalDays', style: num),
                      const TextSpan(text: ' 天   '),
                      TextSpan(text: '$_totalEntries', style: num),
                      const TextSpan(text: ' 笔'),
                    ],
                  ),
                ),
              ),
              _checkinButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  /// 签到：没签是一枚可点的小朱文印「签」，签过变成一行小字
  Widget _checkinButton(ThemeState theme) {
    if (_checkedIn) {
      return Text('今天签过了', style: TextStyle(color: theme.textTertiary, fontSize: 12.5));
    }
    return Semantics(
      button: true,
      label: '签到',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _checkingIn ? null : _doCheckin,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('签到', style: TextStyle(color: theme.accentColor, fontSize: 13)),
              const SizedBox(width: 6),
              Opacity(
                opacity: _checkingIn ? 0.4 : 1,
                child: XqSeal(char: '签', color: theme.sealColor, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 这个月 ──

  Widget _monthCard(ThemeState theme) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final days = DateTime(now.year, now.month + 1, 0).day;
    final lead = first.weekday - 1; // 周一起
    final rows = ((lead + days) / 7).ceil();
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    final recorded = _monthScores.length;

    Widget cell(int day) {
      final score = _monthScores[day];
      final isToday = day == now.day;
      final future = day > now.day;
      return SizedBox(
        height: 38,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 26,
              child: Center(
                child: score != null
                    ? XqPigmentDab(color: Color(moodColors[score] ?? 0xFF7A7871), size: 24, seed: day * 3 + score)
                    : Text(
                        '$day',
                        style: TextStyle(
                          color: isToday ? theme.textPrimary : theme.textTertiary.withAlpha(future ? 110 : 255),
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ),
            Container(width: 10, height: 1.2, color: isToday ? theme.textPrimary : Colors.transparent),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        XqSectionTitle('${chineseNumber(now.month)}月'),
        Semantics(
          button: true,
          label: '这个月记了$recorded天，去心情页',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => MainScaffold.switchToTab(context, 1),
            child: XqSurface(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final n in names)
                        Expanded(
                          child: Center(
                            child: Text(n, style: TextStyle(color: theme.textTertiary, fontSize: 11.5)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var r = 0; r < rows; r++)
                    Row(
                      children: [
                        for (var c = 0; c < 7; c++)
                          Expanded(
                            child: Builder(builder: (_) {
                              final day = r * 7 + c - lead + 1;
                              return day < 1 || day > days ? const SizedBox(height: 38) : cell(day);
                            }),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 我的东西：一行四栏 ──

  Widget _shelf(ThemeState theme) {
    Widget entry(XqIcons icon, String title, String sub, Widget page) => Expanded(
          child: Semantics(
            button: true,
            label: '$title，$sub',
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(context, MaterialPageRoute(builder: (_) => page));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    XqIcon(icon, size: 20, color: theme.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: XqTypography.headlineSmall.copyWith(color: theme.textPrimary, fontSize: 16, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    Widget rule() => Container(width: 0.6, height: 44, color: theme.frameColor);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: theme.frameColor, width: 0.6)),
      ),
      child: Row(
        children: [
          entry(XqIcons.cards, '卡片册', '做过的卡', const CardAlbumPage()),
          rule(),
          entry(XqIcons.book, '素笺', '长一点的', const StoryListPage()),
          rule(),
          entry(XqIcons.hourglass, '胶囊', _capsuleNotify ? '到期提醒' : '提醒关着', const CapsulePage()),
          rule(),
          entry(XqIcons.people, '好友', '朋友的心情', const FriendsPage()),
        ],
      ),
    );
  }

  // ── 纸：深浅 + 四张纸（来历在换纸时浮出，这里不常驻）──

  Widget _paperPicker(ThemeState theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const XqSectionTitle('纸'),
        XqSurface(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _appearanceTabs(theme),
              const SizedBox(height: 14),
              _paperRow(theme, '白天', XqPalette.lights, theme.lightPaper),
              const SizedBox(height: 14),
              _paperRow(theme, '夜里', XqPalette.darks, theme.darkPaper),
            ],
          ),
        ),
      ],
    );
  }

  /// 跟随系统 / 白天 / 夜里：三个字签，选中的下面一道墨线
  Widget _appearanceTabs(ThemeState theme) {
    const items = [
      (XqAppearance.system, '跟随系统'),
      (XqAppearance.light, '总是白天'),
      (XqAppearance.dark, '总是夜里'),
    ];
    return Row(
      children: [
        for (final (a, label) in items)
          Expanded(
            child: Semantics(
              button: true,
              selected: theme.appearance == a,
              label: label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  HapticFeedback.selectionClick();
                  theme.setAppearance(a, origin: d.globalPosition);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: theme.appearance == a ? theme.textPrimary : theme.textTertiary,
                          fontSize: 14,
                          fontWeight: theme.appearance == a ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutQuart,
                        width: theme.appearance == a ? 18 : 0,
                        height: 1.4,
                        color: theme.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _paperRow(ThemeState theme, String label, List<XqPalette> papers, XqPalette chosen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(label, style: TextStyle(color: theme.textTertiary, fontSize: 12)),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            const gap = 10.0;
            final w = ((c.maxWidth - gap * 3) / 4).clamp(48.0, 72.0);
            return Wrap(
              spacing: gap,
              children: [
                for (final p in papers)
                  _PaperSwatch(
                    paper: p,
                    width: w,
                    chosen: p == chosen,
                    inUse: p == theme.palette,
                    underline: theme.textPrimary,
                    onTapUp: (pos) {
                      HapticFeedback.selectionClick();
                      theme.setPaper(p, origin: pos, story: true);
                    },
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // ── 设置 / 关于 ──

  Widget _settingsGroup(ThemeState theme, AppState appState) {
    return XqSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _row(
            theme,
            title: '署名',
            value: appState.displayName.isNotEmpty ? appState.displayName : '还没设',
            onTap: () => _showNicknameDialog(theme, appState),
          ),
          _rule(theme),
          _row(
            theme,
            title: '邮箱',
            value: _boundEmail.isEmpty ? '未绑定' : _boundEmail,
            onTap: () => _showEmailSheet(theme),
          ),
          _rule(theme),
          _row(theme, title: '登录密码', value: '修改', onTap: () => _showPasswordSheet(theme)),
          _rule(theme),
          _row(
            theme,
            title: '胶囊到期提醒',
            value: '',
            trailing: GlowSwitch(value: _capsuleNotify, onChanged: _onCapsuleNotifyChanged),
          ),
        ],
      ),
    );
  }

  Future<void> _onCapsuleNotifyChanged(bool v) async {
    if (v) {
      final alreadyGranted = await NotificationService.areSystemNotificationsEnabled();
      if (alreadyGranted) {
        _setCapsuleNotify(true);
        return;
      }
      final granted = await NotificationService.requestPermissionIfNeeded();
      if (!mounted) return;
      if (!granted) {
        XqToast.info(context, '要先在系统设置里打开通知');
        return;
      }
    }
    _setCapsuleNotify(v);
  }

  Widget _aboutGroup(ThemeState theme) {
    return XqSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _row(
            theme,
            title: '关于拾晴日记',
            value: 'v$appVersion',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
          _rule(theme),
          _row(
            theme,
            title: '隐私政策',
            value: '',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage(isPrivacy: true)),
            ),
          ),
          _rule(theme),
          _row(
            theme,
            title: '用户协议',
            value: '',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage(isPrivacy: false)),
            ),
          ),
          _rule(theme),
          _row(theme, title: '交流群', value: 'QQ 群', onTap: _openQqGroup),
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
        XqToast.info(context, '这台手机上没装 QQ');
      }
    } catch (_) {
      if (!mounted) return;
      XqToast.error(context, '没打开，稍后再试');
    }
  }

  /// 牌记：书末那一小方刊记，双线框里写书名和版次
  Widget _colophon(ThemeState theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(border: Border.all(color: theme.frameColor, width: 0.6)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 9),
          decoration: BoxDecoration(border: Border.all(color: theme.frameColor, width: 0.6)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '拾晴日记',
                style: XqTypography.headlineSmall.copyWith(color: theme.textSecondary, fontSize: 15, letterSpacing: 6),
              ),
              const SizedBox(height: 2),
              Text(
                'v$appVersion',
                style: TextStyle(color: theme.textTertiary, fontSize: 11, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 行 ──

  Widget _rule(ThemeState theme) => Container(height: 0.6, color: theme.borderColor);

  Widget _row(
    ThemeState theme, {
    required String title,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 15)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(color: theme.textTertiary, fontSize: 13),
              ),
            ),
            ?trailing,
            if (onTap != null) ...[
              const SizedBox(width: 4),
              XqIcon(XqIcons.chevronRight, color: theme.frameColor, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// 一张纸样：真的纸色 + 纸纹 + 两道栏线 + 竖写纸名 + 一枚小印。
/// 选中的那张（各自深浅里记住的那张）下面一道墨线；正在用的那张略微提起。
class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({
    required this.paper,
    required this.width,
    required this.chosen,
    required this.inUse,
    required this.underline,
    required this.onTapUp,
  });

  final XqPalette paper;
  final double width;
  final bool chosen;
  final bool inUse;
  final Color underline;
  final ValueChanged<Offset> onTapUp;

  @override
  Widget build(BuildContext context) {
    final p = paper;
    final h = width * 1.32;
    return Semantics(
      button: true,
      selected: chosen,
      label: '${p.name}，${p.paper}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => onTapUp(d.globalPosition),
        child: Column(
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutQuart,
              offset: Offset(0, inUse ? -0.04 : 0),
              child: Container(
                width: width,
                height: h,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: chosen ? p.textSecondary : p.frame, width: chosen ? 1 : 0.6),
                  image: XqPaper.grain(p.fiber, strength: p.dark ? 0.6 : 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(inUse ? 34 : 14),
                      offset: Offset(0, inUse ? 3 : 1),
                      blurRadius: inUse ? 6 : 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 两道乌丝栏
                    for (final x in [0.3, 0.56])
                      Positioned(
                        left: width * x,
                        top: h * 0.1,
                        bottom: h * 0.1,
                        child: Container(width: 0.6, color: p.border),
                      ),
                    Positioned(
                      right: width * 0.12,
                      top: h * 0.1,
                      child: Column(
                        children: [
                          for (final ch in p.name.characters)
                            Text(
                              ch,
                              style: TextStyle(
                                fontFamily: 'Display',
                                fontSize: (width * 0.24).clamp(12.0, 17.0),
                                height: 1.15,
                                color: p.textPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: width * 0.1,
                      bottom: h * 0.08,
                      child: XqSeal(char: p.name.characters.first, color: p.seal, size: (width * 0.28).clamp(14.0, 20.0)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: chosen ? 14 : 0,
              height: 1.4,
              color: underline,
            ),
          ],
        ),
      ),
    );
  }
}
