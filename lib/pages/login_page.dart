import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../theme/xq_decorations.dart';
import '../widgets/auth_frame.dart';
import '../widgets/main_scaffold.dart';
import '../services/notification_service.dart';
import '../main.dart';
import 'register_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emailPwCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _emailObscure = true;
  bool _useEmail = false;
  String? _error;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onInputChanged);
    _pwCtrl.addListener(_onInputChanged);
    _emailCtrl.addListener(_onInputChanged);
    _emailPwCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onInputChanged);
    _pwCtrl.removeListener(_onInputChanged);
    _emailCtrl.removeListener(_onInputChanged);
    _emailPwCtrl.removeListener(_onInputChanged);
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _emailCtrl.dispose();
    _emailPwCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _phoneError = null;
    });
  }

  bool get _phoneValid => _isValidPhone(_phoneCtrl.text.trim());
  bool get _emailValid =>
      _emailCtrl.text.trim().contains('@') &&
      _emailCtrl.text.trim().contains('.');
  bool get _formValid => _useEmail
      ? _emailValid && _emailPwCtrl.text.isNotEmpty
      : _phoneValid && _pwCtrl.text.isNotEmpty;

  bool _isValidPhone(String phone) {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) return false;
    const validPrefixes = {
      '130',
      '131',
      '132',
      '133',
      '134',
      '135',
      '136',
      '137',
      '138',
      '139',
      '145',
      '146',
      '147',
      '148',
      '149',
      '150',
      '151',
      '152',
      '153',
      '155',
      '156',
      '157',
      '158',
      '159',
      '162',
      '165',
      '166',
      '167',
      '170',
      '171',
      '172',
      '173',
      '174',
      '175',
      '176',
      '177',
      '178',
      '180',
      '181',
      '182',
      '183',
      '184',
      '185',
      '186',
      '187',
      '188',
      '189',
      '190',
      '191',
      '193',
      '195',
      '196',
      '197',
      '198',
      '199',
    };
    return validPrefixes.contains(phone.substring(0, 3));
  }

  Future<void> _login() async {
    if (_loading) return;
    if (!_useEmail && !_phoneValid) {
      setState(() => _phoneError = '请输入正确的11位手机号');
      return;
    }
    if (_useEmail && !_emailValid) {
      setState(() => _error = '请输入正确的邮箱地址');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final Map<String, dynamic> data;
      if (_useEmail) {
        data = await Api.emailLogin(_emailCtrl.text.trim(), _emailPwCtrl.text);
      } else {
        data = await Api.login(_phoneCtrl.text.trim(), _pwCtrl.text);
      }
      final dn = data['display_name']?.toString() ?? '';
      if (!mounted) return;
      context.read<AppState>().setDisplayName(dn);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScaffold(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              ),
        ),
      );
      NotificationService.openPendingCapsuleIfAny(appNavigatorKey);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '网络连接失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              XqAuthBackdrop(theme: theme),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        XqAuthHero(theme: theme, title: '拾晴日记'),
                        const SizedBox(height: 22),
                        XqAuthCard(
                          theme: theme,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '欢迎回来',
                                style: XqTypography.headlineMedium.copyWith(
                                  color: theme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '欢迎回来，今天想记点什么？',
                                style: XqTypography.bodySmall.copyWith(
                                  color: theme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 手机号 / 邮箱切换
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.surfaceAlpha,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _useEmail = false),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !_useEmail
                                                ? theme.cardColor
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: !_useEmail
                                                ? XqDecorations.shadowSubtle(dark: theme.isDark)
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.phone_iphone_rounded,
                                                size: 16,
                                                color: !_useEmail
                                                    ? theme.accentColor
                                                    : theme.textTertiary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '手机号',
                                                style: XqTypography.labelMedium.copyWith(
                                                  color: !_useEmail
                                                      ? theme.accentColor
                                                      : theme.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _useEmail = true),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _useEmail
                                                ? theme.cardColor
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: _useEmail
                                                ? XqDecorations.shadowSubtle(dark: theme.isDark)
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.email_outlined,
                                                size: 16,
                                                color: _useEmail
                                                    ? theme.accentColor
                                                    : theme.textTertiary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '邮箱',
                                                style: XqTypography.labelMedium.copyWith(
                                                  color: _useEmail
                                                      ? theme.accentColor
                                                      : theme.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_useEmail) ...[
                                XqAuthInput(
                                  controller: _emailCtrl,
                                  label: '邮箱',
                                  hint: '请输入邮箱地址',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),
                                XqAuthInput(
                                  controller: _emailPwCtrl,
                                  label: '密码',
                                  hint: '请输入密码',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _emailObscure,
                                  suffix: IconButton(
                                    onPressed: () => setState(
                                      () => _emailObscure = !_emailObscure,
                                    ),
                                    icon: Icon(
                                      _emailObscure
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: theme.textSecondary,
                                    ),
                                  ),
                                  onSubmitted: (_) => _login(),
                                ),
                              ] else ...[
                                XqAuthInput(
                                  controller: _phoneCtrl,
                                  label: '手机号',
                                  hint: '请输入 11 位手机号',
                                  icon: Icons.phone_iphone_rounded,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  error: _phoneError,
                                ),
                                const SizedBox(height: 14),
                                XqAuthInput(
                                  controller: _pwCtrl,
                                  label: '密码',
                                  hint: '请输入密码',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscure,
                                  suffix: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: theme.textSecondary,
                                    ),
                                  ),
                                  onSubmitted: (_) => _login(),
                                ),
                              ],
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _error == null
                                    ? const SizedBox(height: 18)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          _error!,
                                          key: ValueKey(_error),
                                          style: XqTypography.bodySmall.copyWith(
                                            color: theme.errorColor,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 10),
                              XqAuthButton(
                                label: '登录',
                                loading: _loading,
                                active: _formValid,
                                onTap: _login,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ResetPasswordPage(),
                                          ),
                                        ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    '忘记密码？',
                                    style: XqTypography.bodySmall.copyWith(
                                      color: theme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          child: Text(
                            '还没有账号？创建一个',
                            style: XqTypography.button.copyWith(
                              color: theme.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
