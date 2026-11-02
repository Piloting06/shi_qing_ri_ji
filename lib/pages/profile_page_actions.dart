part of 'profile_page.dart';

extension _ProfilePageActions on _ProfilePageState {
  Future<void> _loadProfileInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      _setState(() {
        _phone = prefs.getString(StorageKeys.phone) ?? '';
        _boundEmail = prefs.getString(StorageKeys.email) ?? '';
        _capsuleNotify = prefs.getBool(StorageKeys.capsuleNotify) ?? true;
      });
    }
    // Fetch from server to stay in sync
    try {
      final profile = await Api.getProfile();
      if (mounted) {
        final email = profile['email'] as String? ?? '';
        _setState(() => _boundEmail = email);
        final prefs = await SharedPreferences.getInstance();
        if (email.isNotEmpty) {
          await prefs.setString(StorageKeys.email, email);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCheckin() async {
    try {
      final s = await Api.getCheckinStatus();
      if (mounted) {
        _setState(() {
          _checkedIn = s['checked_in'] == true || s['checked_in'] == 1;
          _consecutive = s['consecutive_days'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    final fileName = _avatarFileName();
    final storedFile = prefs.getString(_ProfilePageState._avatarFileKey);
    if (storedFile != null && storedFile.isNotEmpty) {
      final file = File(p.join(dir.path, storedFile));
      if (file.existsSync()) {
        if (mounted) _setState(() => _avatarPath = file.path);
        return;
      }
      await prefs.remove(_ProfilePageState._avatarFileKey);
    }

    // Try loading user-specific avatar
    final userFile = File(p.join(dir.path, fileName));
    if (userFile.existsSync()) {
      await prefs.setString(_ProfilePageState._avatarFileKey, fileName);
      if (mounted) _setState(() => _avatarPath = userFile.path);
      return;
    }

    // Legacy migration
    final legacyPath = prefs.getString(_ProfilePageState._legacyAvatarPathKey);
    if (legacyPath != null && legacyPath.isNotEmpty) {
      final legacyFile = File(legacyPath);
      if (legacyFile.existsSync()) {
        final dest = File(p.join(dir.path, fileName));
        if (p.normalize(legacyFile.path) != p.normalize(dest.path)) {
          await legacyFile.copy(dest.path);
        }
        await prefs.setString(_ProfilePageState._avatarFileKey, fileName);
        await prefs.remove(_ProfilePageState._legacyAvatarPathKey);
        if (mounted) _setState(() => _avatarPath = dest.path);
        return;
      }
      await prefs.remove(_ProfilePageState._legacyAvatarPathKey);
    }

    if (mounted) _setState(() => _avatarPath = null);
  }

  Future<void> _pickAvatar() async {
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        imageQuality: 80,
      );
      if (img == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final fileName = _avatarFileName();
      final dest = File(p.join(dir.path, fileName));
      await File(img.path).copy(dest.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ProfilePageState._avatarFileKey, _avatarFileName());
      await prefs.remove(_ProfilePageState._legacyAvatarPathKey);
      if (!mounted) return;
      _setState(() => _avatarPath = dest.path);
      XqToast.success(context, '头像已保存');
    } catch (_) {
      if (mounted) XqToast.error(context, '头像没存上，再试一次？');
    }
  }

  Future<void> _doCheckin() async {
    if (_checkedIn || _checkingIn) return;
    HapticFeedback.lightImpact();
    _setState(() => _checkingIn = true);
    try {
      final r = await Api.checkin();
      if (mounted) {
        _setState(() {
          _checkedIn = true;
          _consecutive = r['consecutive_days'] ?? _consecutive;
        });
        XqToast.success(context, '今日已记录');
      }
    } catch (_) {
      if (mounted) XqToast.error(context, '签到失败，请稍后重试');
    } finally {
      if (mounted) _setState(() => _checkingIn = false);
    }
  }

  Future<void> _updateName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _saving) return;
    _setState(() => _saving = true);
    try {
      await Api.updateDisplayName(name);
      if (mounted) {
        context.read<AppState>().setDisplayName(name);
        _nameCtrl.clear();
        XqToast.success(context, '新名字真好听～');
      }
    } catch (_) {
      if (mounted) XqToast.error(context, '名字保存失败，请稍后重试');
    } finally {
      if (mounted) _setState(() => _saving = false);
    }
  }

  Future<void> _setCapsuleNotify(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.capsuleNotify, value);
    if (!mounted) return;
    _setState(() => _capsuleNotify = value);
  }

  Future<void> _changePassword() async {
    if (_oldPwCtrl.text.isEmpty || _newPwCtrl.text.length < 6 || _saving) {
      return;
    }
    _setState(() => _saving = true);
    try {
      await Api.changePassword(_oldPwCtrl.text, _newPwCtrl.text);
      if (mounted) {
        _oldPwCtrl.clear();
        _newPwCtrl.clear();
        XqToast.success(context, '密码已更改');
      }
    } catch (_) {
      if (mounted) XqToast.error(context, '修改失败，请检查当前密码');
    } finally {
      if (mounted) _setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final theme = context.read<ThemeState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: theme.cardColor,
        title: Text(
          '注销账号',
          style: TextStyle(
            color: theme.errorColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text('注销后会退出当前账号，并释放手机号。重新注册会创建一个全新账号。'),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: theme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.errorColor,
            ),
            child: const Text('确定注销'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteAccount();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      context.read<AppState>().clearUser();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) XqToast.error(context, '注销失败，请稍后重试');
    }
  }

  Future<void> _logout() async {
    final theme = context.read<ThemeState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
            border: Border.all(color: theme.borderColor.withAlpha(80)),
            boxShadow: XqDecorations.shadowSubtle(dark: theme.isDark),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withAlpha(22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: theme.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '退出登录',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '退出后手机上的记录会被清理，重新登录就好',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // 切换账号
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'switch'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.accentColor,
                      side: BorderSide(color: theme.accentColor.withAlpha(120)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 18, color: theme.accentColor),
                        const SizedBox(width: 6),
                        Text(
                          '切换账号',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 退出
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'logout'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.errorColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.power_settings_new_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '退出当前账号',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // 取消
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(ctx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: theme.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 彻底注销（低调）
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(ctx, 'delete'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '彻底注销账号',
                      style: TextStyle(
                        color: theme.textTertiary.withAlpha(140),
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.textTertiary.withAlpha(100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == 'logout' || result == 'switch') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.token);
      await prefs.remove(StorageKeys.phone);
      await prefs.remove(StorageKeys.username);
      await prefs.remove(StorageKeys.displayName);
      await prefs.remove(StorageKeys.email);
      await prefs.remove(_ProfilePageState._avatarFileKey);
      if (!mounted) return;
      context.read<AppState>().clearUser();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } else if (result == 'delete') {
      _deleteAccount();
    }
  }
  Future<void> _saveCard(GlobalKey key, String name) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'theme_$name.png'));
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Gal.putImage(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name 已保存到相册'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请检查相册权限')));
    }
  }

  Future<void> _shareCard(GlobalKey key, String name) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'theme_$name.png'));
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '拾晴日记 · $name主题\n$name — 记录天气，也记录你',
        ),
      );
    } catch (e) {
      // share_plus handles its own errors
    }
  }

  Map<String, String> _themeDetail(String mode) {
    return switch (mode) {
      'warm' => {
        'nickname': '晴日暖白',
        'creator':
            '我喜欢被阳光包裹的感觉。窗边那张桌子，一本摊开的日记本，笔尖在纸上沙沙地走，'
            '旁边一杯热茶冒着气。这种温暖不是燥热，是让人忍不住想跟自己说几句话的那种安宁。'
            '这是我给拾晴日记选的第一套颜色。',
        'title': '不只是一种颜色',
        'detail':
            '暖白色不是白色加了黄，是一种被时间浸润后的纸张色。'
            '它的温和不刺眼，适合长时间书写。棕色强调色像一杯手冲，'
            '不过分甜，不刻意苦，刚好能托住情绪的起伏。'
            '这大概是所有日记应用都想成为的样子：一个让你愿意坐下来、慢慢写的地方。',
      },
      'dark' => {
        'nickname': '静夜深蓝',
        'creator':
            '有时候就是半夜才有话想说。白天的话是社交用的，夜里的话才是自己的。'
            '关掉灯，只剩屏幕的光，指尖在暗色界面上敲字很安静，不会吵醒心里那些还没理清的念头。'
            '我需要一个不怕黑的主题。',
        'title': '黑夜是伴侣，不是敌人',
        'detail':
            '深蓝底色带一点紫调，避免了纯黑的压抑感，像是在月光下写字而不是在黑洞里。'
            '薰衣草蓝的强调色保留了夜间的温柔，不会刺眼，不会让深夜的情绪觉得被冒犯。'
            '这是一个为独处时刻准备的空间：不用假装开心，不用强撑白天的样子。',
      },
      'mint' => {
        'nickname': '雾感薄荷',
        'creator':
            '有些早晨推开窗，空气里还有昨晚下雨的味道，凉凉的、带着植物的清新。'
            '那种感觉应该被记录下来。我觉得写东西不一定要很沉重，'
            '有时候就是随手记一个念头、一张喜欢的外卖单、一句路过听到的话。清爽就好。',
        'title': '轻，但不轻薄',
        'detail':
            '低饱和的青碧绿像薄荷叶在杯底慢慢舒展，不是鲜艳夺目的荧光绿，'
            '而是被水雾蒙了一层的那种温柔绿意。它让写日记这件事变得轻快起来，'
            '像是在雨后林间散步，深呼吸一口，所有烦恼都能先放一放。',
      },
      _ => {
        'nickname': '豆沙柔粉',
        'creator':
            '这个颜色是我心里的隐藏款。有人说粉色太甜，那是没找到对的灰调。'
            '豆沙粉像是冬天大衣口袋里的一颗糖果，或者咖啡馆角落里铺着的那种旧丝绒沙发。'
            '它不张扬，但每次看到都会心里一动。我把它收在四个主题里，像是给懂的人留的小暗号。',
        'title': '被低估的温柔力量',
        'detail':
            '灰调豆沙粉在哑光质感下呈现出一种成熟的浪漫：不是少女梦里的粉红泡泡，'
            '而是成年后还愿意相信美好的那种笃定。暖棕色的强调色让整个界面有了温度，'
            '像一封手写信的封蜡，或一杯温水，不惊艳，但能安抚你一天的疲惫。'
            '这是一款值得细细品味的颜色，也是四款中最特别的存在。',
      },
    };
  }
}
