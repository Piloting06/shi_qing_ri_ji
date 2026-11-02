import '../widgets/xq_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../widgets/auth_frame.dart';
import '../widgets/main_scaffold.dart';
import '../services/notification_service.dart';
import '../main.dart';
import '../theme/xq_decorations.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  final _customQuestionCtrl = TextEditingController();
  final _customAnswerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _obscure2 = true;
  bool _useEmail = false;
  bool _sendingCode = false;
  int _codeCountdown = 0;

  String _questionType = 'choice';
  int _choiceAnswer = 0;
  DateTime? _dateAnswer;

  static const _choiceQuestions = [
    '你第一次养宠物是在几岁？',
    '你小时候最喜欢的玩具是什么？',
    '你的小学叫什么名字？',
    '你妈妈的生日是哪天？',
  ];
  static const _dateQuestions = ['你最重要的纪念日是？', '你第一次离开家乡是哪天？', '你最难忘的旅行是哪天？'];

  @override
  void initState() {
    super.initState();
    for (final ctrl in [
      _phoneCtrl,
      _pwCtrl,
      _pw2Ctrl,
      _customQuestionCtrl,
      _customAnswerCtrl,
      _emailCtrl,
      _emailCodeCtrl,
    ]) {
      ctrl.addListener(_onInputChanged);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [
      _phoneCtrl,
      _pwCtrl,
      _pw2Ctrl,
      _customQuestionCtrl,
      _customAnswerCtrl,
      _emailCtrl,
      _emailCodeCtrl,
    ]) {
      ctrl.removeListener(_onInputChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onInputChanged() {
    if (!mounted || _error == null) return;
    setState(() => _error = null);
  }

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

  bool get _emailValid =>
      _emailCtrl.text.trim().contains('@') &&
      _emailCtrl.text.trim().contains('.');
  bool get _formValid {
    if (_useEmail) {
      final passwordOk =
          _pwCtrl.text.length >= 6 && _pwCtrl.text == _pw2Ctrl.text;
      final questionOk = _questionType == 'custom'
          ? _customQuestionCtrl.text.trim().isNotEmpty &&
                _customAnswerCtrl.text.trim().isNotEmpty
          : _questionType == 'date'
          ? _dateAnswer != null
          : true;
      return _emailValid &&
          _emailCodeCtrl.text.trim().isNotEmpty &&
          passwordOk &&
          questionOk;
    }
    final phoneOk = _isValidPhone(_phoneCtrl.text.trim());
    final passwordOk =
        _pwCtrl.text.length >= 6 && _pwCtrl.text == _pw2Ctrl.text;
    final questionOk = _questionType == 'custom'
        ? _customQuestionCtrl.text.trim().isNotEmpty &&
              _customAnswerCtrl.text.trim().isNotEmpty
        : _questionType == 'date'
        ? _dateAnswer != null
        : true;
    return phoneOk && passwordOk && questionOk;
  }

  Future<void> _sendEmailCode() async {
    if (_sendingCode || !_emailValid) return;
    setState(() => _sendingCode = true);
    try {
      await Api.sendEmailCode(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _codeCountdown = 60);
      _startCountdown();
      XqToast.info(context, '验证码已发送');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '发送失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _codeCountdown <= 0) return;
      setState(() => _codeCountdown--);
      _startCountdown();
    });
  }

  Future<void> _register() async {
    if (_loading) return;
    if (!_formValid) {
      setState(() => _error = '请确认所有信息都填写正确');
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
        data = await Api.emailRegister(
          _emailCtrl.text.trim(),
          _pwCtrl.text,
          _emailCodeCtrl.text.trim(),
        );
      } else {
        final question = switch (_questionType) {
          'date' => _dateQuestions[0],
          'choice' => _choiceQuestions[0],
          _ => _customQuestionCtrl.text.trim(),
        };
        final answer = switch (_questionType) {
          'choice' => '$_choiceAnswer',
          'date' => _dateAnswer?.toIso8601String() ?? '',
          _ => _customAnswerCtrl.text.trim(),
        };
        data = await Api.register(
          _phoneCtrl.text.trim(),
          _pwCtrl.text,
          questionType: _questionType,
          question: question,
          answer: answer,
        );
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateAnswer = picked;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          XqAuthBackdrop(theme: theme),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        XqAuthHero(theme: theme, title: '欢迎来到拾晴日记', size: 58),
                        const SizedBox(height: 20),
                        XqAuthCard(
                          theme: theme,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '创建账号',
                                style: XqTypography.headlineMedium.copyWith(
                                  color: theme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _useEmail
                                    ? '用邮箱注册，给心情找一个安心的地方。'
                                    : '一个手机号就够了，帮你记住每一天的自己。',
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
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withAlpha(
                                                            theme.isDark
                                                                ? 30
                                                                : 10,
                                                          ),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ]
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
                                                style: XqTypography.bodySmall.copyWith(
                                                  color: !_useEmail
                                                      ? theme.accentColor
                                                      : theme.textTertiary,
                                                  fontWeight: FontWeight.w600,
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
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withAlpha(
                                                            theme.isDark
                                                                ? 30
                                                                : 10,
                                                          ),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ]
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
                                                style: XqTypography.bodySmall.copyWith(
                                                  color: _useEmail
                                                      ? theme.accentColor
                                                      : theme.textTertiary,
                                                  fontWeight: FontWeight.w600,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: XqAuthInput(
                                        controller: _emailCodeCtrl,
                                        label: '验证码',
                                        hint: '6位验证码',
                                        icon: Icons.pin_outlined,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: SizedBox(
                                        height: 44,
                                        width: 120,
                                        child: OutlinedButton(
                                          onPressed:
                                              (_sendingCode ||
                                                  _codeCountdown > 0 ||
                                                  !_emailValid)
                                              ? null
                                              : _sendEmailCode,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: theme.accentColor,
                                            disabledForegroundColor: theme
                                                .accentColor
                                                .withAlpha(100),
                                            side: BorderSide(
                                              color: theme.accentColor
                                                  .withAlpha(140),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: _codeCountdown > 0
                                              ? Text(
                                                  '${_codeCountdown}s',
                                                  style: XqTypography.bodySmall,
                                                )
                                              : _sendingCode
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text(
                                                  '发送验证码',
                                                  style: XqTypography.button,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
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
                                ),
                              ],
                              const SizedBox(height: 14),
                              XqAuthInput(
                                controller: _pwCtrl,
                                label: '密码',
                                hint: '至少 6 位',
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
                              ),
                              const SizedBox(height: 14),
                              XqAuthInput(
                                controller: _pw2Ctrl,
                                label: '确认密码',
                                hint: '再次输入密码',
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscure2,
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure2 = !_obscure2),
                                  icon: Icon(
                                    _obscure2
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!_useEmail) _securityQuestion(theme),
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
                                label: '创建账号',
                                loading: _loading,
                                active: _formValid,
                                onTap: _register,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          child: Text(
                            '已有账号？去登录',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityQuestion(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceAlpha,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '安全问题',
            style: XqTypography.bodyMedium.copyWith(
              color: theme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '用于以后找回账号，请选择一个自己记得住的答案。',
            style: XqTypography.bodySmall.copyWith(
              color: theme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _qTypeBtn('choice', '选择题', theme),
              _qTypeBtn('date', '日期题', theme),
              _qTypeBtn('custom', '自定义', theme),
            ],
          ),
          const SizedBox(height: 12),
          if (_questionType == 'choice') ...[
            Text(
              _choiceQuestions[0],
              style: XqTypography.bodyMedium.copyWith(color: theme.textPrimary),
            ),
            Slider(
              value: _choiceAnswer.toDouble(),
              min: 0,
              max: 30,
              divisions: 30,
              activeColor: theme.accentColor,
              inactiveColor: theme.borderColor,
              label: '$_choiceAnswer 岁',
              onChanged: (v) => setState(() => _choiceAnswer = v.round()),
            ),
          ] else if (_questionType == 'date') ...[
            Text(
              _dateQuestions[0],
              style: XqTypography.bodyMedium.copyWith(color: theme.textPrimary),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(
                _dateAnswer == null
                    ? '选择日期'
                    : '${_dateAnswer!.year}-${_dateAnswer!.month.toString().padLeft(2, '0')}-${_dateAnswer!.day.toString().padLeft(2, '0')}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.accentColor,
                side: BorderSide(color: theme.accentColor.withAlpha(90)),
                minimumSize: const Size(44, 42),
              ),
            ),
          ] else ...[
            XqAuthInput(
              controller: _customQuestionCtrl,
              label: '自定义问题',
              hint: '比如：我最怕什么动物？',
              icon: Icons.help_outline_rounded,
            ),
            const SizedBox(height: 10),
            XqAuthInput(
              controller: _customAnswerCtrl,
              label: '答案',
              hint: '只有你知道的答案',
              icon: Icons.edit_note_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _qTypeBtn(String type, String label, ThemeState theme) {
    final active = _questionType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() {
        _questionType = type;
        _error = null;
      }),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? theme.accentColor.withAlpha(24) : theme.cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? theme.accentColor : theme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: XqTypography.labelMedium.copyWith(
            color: active ? theme.accentColor : theme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
