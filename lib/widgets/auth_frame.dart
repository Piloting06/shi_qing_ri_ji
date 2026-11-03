import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';

/// 登录/注册共用组件（素笺规范）：
/// 无外层大卡片、无金色图标；品牌 = 朱砂小印 + 宋体名；
/// 输入框无边框内图标，控件边框走 controlBorder。

class XqAuthBackdrop extends StatelessWidget {
  final ThemeState theme;

  const XqAuthBackdrop({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    // 烟雨雾：两团极淡的冷色雾，替代旧彩色光晕
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -60,
          child: _AuthMist(size: 200, color: theme.accentColor.withAlpha(theme.isDark ? 16 : 12)),
        ),
        Positioned(
          left: -70,
          bottom: 70,
          child: _AuthMist(size: 160, color: theme.inkLight.withAlpha(theme.isDark ? 14 : 8)),
        ),
      ],
    );
  }
}

class _AuthMist extends StatelessWidget {
  final double size;
  final Color color;

  const _AuthMist({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

/// 品牌头：朱砂小印「拾」+ 宋体标题。icon 参数保留兼容旧调用，不再使用。
class XqAuthHero extends StatelessWidget {
  final ThemeState theme;
  final String title;
  final IconData icon;
  final double size;

  const XqAuthHero({
    super.key,
    required this.theme,
    required this.title,
    this.icon = Icons.auto_stories_outlined,
    this.size = 68,
  });

  @override
  Widget build(BuildContext context) {
    final sealSize = 40.0;
    return Column(
      children: [
        Container(
          width: sealSize,
          height: sealSize,
          decoration: BoxDecoration(
            border: Border.all(color: theme.sealColor, width: 1.6),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.center,
          child: Text(
            '拾',
            style: TextStyle(
              color: theme.sealColor,
              fontSize: sealSize * 0.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'SerifSC',
              fontFamilyFallback: ['Noto Serif SC', 'Songti SC'],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w500,
            fontFamily: 'SerifSC',
            fontFamilyFallback: ['Noto Serif SC', 'Songti SC'],
            height: 1.35,
            letterSpacing: title.length <= 4 ? 4 : 1,
          ),
        ),
      ],
    );
  }
}

/// 表单容器：素笺无外层卡片，仅保留布局分组语义。
class XqAuthCard extends StatelessWidget {
  final ThemeState theme;
  final Widget child;

  const XqAuthCard({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// 输入框：标签在上，控件边框走 controlBorder，框内不放图标。
class XqAuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon; // 兼容旧调用签名，不再渲染
  final bool obscure;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final void Function(String)? onSubmitted;
  final String? error;

  const XqAuthInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.suffix,
    this.onSubmitted,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: XqTypography.labelMedium.copyWith(color: theme.textSecondary),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: keyboardType == TextInputType.phone ? 11 : null,
          onSubmitted: onSubmitted,
          style: XqTypography.bodyLarge.copyWith(color: theme.textPrimary),
          cursorColor: theme.accentColor,
          decoration: InputDecoration(
            counterText: '',
            suffixIcon: suffix,
            hintText: hint,
            errorText: error,
          ),
        ),
      ],
    );
  }
}

/// 主按钮：禁用态用边框底 + tertiary 字，清晰可读。
class XqAuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool active;
  final VoidCallback onTap;

  const XqAuthButton({
    super.key,
    required this.label,
    required this.loading,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final enabled = active && !loading;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: theme.accentColor,
          foregroundColor: theme.textOnAccent,
          disabledBackgroundColor:
              theme.isDark ? theme.borderColor.withAlpha(90) : theme.borderColor,
          disabledForegroundColor: theme.textTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.textOnAccent,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              ),
      ),
    );
  }
}
