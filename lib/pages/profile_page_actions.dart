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
      if (mounted) XqToast.error(context, '头像没存上，再试一次');
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
        XqToast.success(context, '名字改好了');
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
            fontWeight: FontWeight.w600,
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
                  child: XqIcon(XqIcons.logout,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '退出后清掉这台手机上的缓存，记录还在账号里',
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
                        XqIcon(XqIcons.swap, size: 18, color: theme.accentColor),
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
                        const XqIcon(XqIcons.logout, size: 18),
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
          text: '拾晴日记 · $name',
        ),
      );
    } catch (e) {
      // share_plus handles its own errors
    }
  }

  Map<String, String> _themeDetail(String mode) {
    return switch (mode) {
      'sujian_dark' => {
        'nickname': '磁青',
        'creator': '古人把纸用靛蓝染深，叫磁青纸，再用金粉调胶在上面写经。夜里用手机，深底比白底舒服。',
        'title': '深青纸，泥金字',
        'detail': '底色是偏青的深蓝，不是纯黑；按钮和日期用泥金色；正文是月白，不刺眼。印章仍然用朱砂。',
      },
      _ => {
        'nickname': '素笺',
        'creator': '参照明代的《十竹斋笺谱》和荣宝斋的木版水印信笺。笺本来就是写字、寄信用的纸。',
        'title': '每天一张笺',
        'detail': '页面是裱绫，卡片是一张张笺，用细墨线框起来；颜色只有纸、墨、朱砂三样，心情用国画颜料。首页的天每天按天气和节气重新印一张。',
      },
    };
  }
}
