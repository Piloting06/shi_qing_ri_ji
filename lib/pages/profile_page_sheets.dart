part of 'profile_page.dart';

extension _ProfilePageSheets on _ProfilePageState {
  void _showEmailSheet(ThemeState theme) {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    var sending = false;
    var countdown = 0;
    var binding = false;

    void startCountdown() {
      Future.delayed(const Duration(seconds: 1), () {
        if (countdown <= 0) return;
        countdown--;
        if (mounted) _setState(() {});
        startCountdown();
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _boundEmail.isEmpty ? '绑定邮箱' : '更换邮箱',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_boundEmail.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '当前: $_boundEmail',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setSheetState(() {}),
                      style: TextStyle(color: theme.textPrimary, fontSize: 14),
                      cursorColor: theme.accentColor,
                      decoration: InputDecoration(
                        labelText: '邮箱地址',
                        labelStyle: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: theme.accentColor,
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.accentColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 14,
                            ),
                            cursorColor: theme.accentColor,
                            decoration: InputDecoration(
                              labelText: '验证码',
                              labelStyle: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.pin_outlined,
                                color: theme.accentColor,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.accentColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          height: 44,
                          child: OutlinedButton(
                            onPressed:
                                (sending ||
                                    countdown > 0 ||
                                    !emailCtrl.text.contains('@') ||
                                    !emailCtrl.text.contains('.'))
                                ? null
                                : () async {
                                    sending = true;
                                    setSheetState(() {});
                                    try {
                                      await Api.sendEmailCode(
                                        emailCtrl.text.trim(),
                                      );
                                      countdown = 60;
                                      sending = false;
                                      if (mounted) _setState(() {});
                                      startCountdown();
                                    } catch (_) {
                                      sending = false;
                                      if (mounted) _setState(() {});
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.accentColor,
                              disabledForegroundColor: theme.accentColor
                                  .withAlpha(100),
                              side: BorderSide(
                                color: theme.accentColor.withAlpha(140),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: countdown > 0
                                ? Text(
                                    '${countdown}s',
                                    style: const TextStyle(fontSize: 13),
                                  )
                                : sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    '发送验证码',
                                    style: TextStyle(fontSize: 12),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: binding
                            ? null
                            : () async {
                                if (emailCtrl.text.trim().isEmpty ||
                                    codeCtrl.text.isEmpty) {
                                  return;
                                }
                                binding = true;
                                setSheetState(() {});
                                try {
                                  await Api.bindEmail(
                                    emailCtrl.text.trim(),
                                    codeCtrl.text,
                                  );
                                  final email = emailCtrl.text.trim();
                                  _setState(() => _boundEmail = email);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString(StorageKeys.email, email);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    XqToast.success(context, '邮箱绑定成功');
                                  }
                                } on ApiException catch (e) {
                                  binding = false;
                                  setSheetState(() {});
                                  if (mounted) {
                                    XqToast.error(context, e.message);
                                  }
                                } catch (_) {
                                  binding = false;
                                  setSheetState(() {});
                                  if (mounted) {
                                    XqToast.error(context, '绑定失败，请稍后重试');
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
                        child: binding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('确认绑定'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNicknameDialog(ThemeState theme, AppState appState) {
    final ctrl = TextEditingController(
      text: appState.displayName.isNotEmpty ? appState.displayName : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          '修改昵称',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: theme.textPrimary),
          cursorColor: theme.accentColor,
          decoration: InputDecoration(
            hintText: '输入新的昵称',
            hintStyle: TextStyle(color: theme.textTertiary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: theme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              _nameCtrl.text = name;
              _updateName();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: theme.textOnAccent,
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showPasswordSheet(ThemeState theme) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscureOld = true;
    var obscureNew = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '修改密码',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: oldCtrl,
                    obscureText: obscureOld,
                    style: TextStyle(color: theme.textPrimary, fontSize: 14),
                    cursorColor: theme.accentColor,
                    decoration: InputDecoration(
                      labelText: '当前密码',
                      labelStyle: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: theme.accentColor,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility_off : Icons.visibility,
                          color: theme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscureOld = !obscureOld),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    style: TextStyle(color: theme.textPrimary, fontSize: 14),
                    cursorColor: theme.accentColor,
                    decoration: InputDecoration(
                      labelText: '新密码',
                      labelStyle: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_reset,
                        color: theme.accentColor,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                          color: theme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    style: TextStyle(color: theme.textPrimary, fontSize: 14),
                    cursorColor: theme.accentColor,
                    decoration: InputDecoration(
                      labelText: '确认新密码',
                      labelStyle: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_reset,
                        color: theme.accentColor,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        if (oldCtrl.text.isEmpty ||
                            newCtrl.text.length < 6 ||
                            newCtrl.text != confirmCtrl.text) {
                          return;
                        }
                        _oldPwCtrl.text = oldCtrl.text;
                        _newPwCtrl.text = newCtrl.text;
                        _changePassword();
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.textOnAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('确认修改'),
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

  // ── Helpers ──

  String _themeSceneDesc(String mode) {
    return switch (mode) {
      'dark' => '深夜被窝里',
      'mint' => '雨后清晨',
      'blush' => '咖啡店角落',
      _ => '午后窗边',
    };
  }

  Color _readableTextOn(Color bg) {
    return (bg.computeLuminance() > 0.5)
        ? const Color(0xFF333333)
        : const Color(0xFFEEEEEE);
  }

  void _showThemeDetail(
    String mode,
    String name,
    List<Color> colors,
    String scene,
  ) {
    final d = _themeDetail(mode);
    final repaintKey = GlobalKey();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, anim, child) {
            return Transform.scale(
              scale: 0.92 + 0.08 * anim,
              child: Opacity(
                opacity: anim.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: RepaintBoundary(
          key: repaintKey,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colors[2],
              border: Border.all(color: colors[0].withAlpha(60), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withAlpha(40),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color header strip
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors[0], colors[1]],
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: colors
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c,
                                    border: Border.all(
                                      color: Colors.white.withAlpha(180),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(30),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: _readableTextOn(colors[2]),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$scene，”${d['nickname']}”',
                          style: TextStyle(
                            color: _readableTextOn(colors[2]).withAlpha(180),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors[0].withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors[0].withAlpha(30)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: colors[0],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  d['creator']!,
                                  style: TextStyle(
                                    color: _readableTextOn(
                                      colors[2],
                                    ).withAlpha(210),
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          d['title']!,
                          style: TextStyle(
                            color: _readableTextOn(colors[2]),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d['detail']!,
                          style: TextStyle(
                            color: _readableTextOn(colors[2]).withAlpha(200),
                            fontSize: 12,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Buttons row
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () => _saveCard(repaintKey, name),
                                  icon: const Icon(Icons.download, size: 17),
                                  label: const Text(
                                    '保存',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors[0],
                                    side: BorderSide(
                                      color: colors[0].withAlpha(100),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: FilledButton.icon(
                                  onPressed: () => _shareCard(repaintKey, name),
                                  icon: const Icon(Icons.share, size: 17),
                                  label: const Text(
                                    '分享',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors[0],
                                    foregroundColor:
                                        colors[0].computeLuminance() > 0.5
                                        ? const Color(0xFF222222)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
