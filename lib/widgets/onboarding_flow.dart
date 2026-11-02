import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../constants/keys.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';

class OnboardingFlow {
  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final dn = prefs.getString(StorageKeys.displayName) ?? '';
    final onboarded = prefs.getBool(StorageKeys.onboardingDone) ?? false;

    if (!context.mounted) return;
    final appDn = context.read<AppState>().displayName;

    if (dn.isEmpty && appDn.isEmpty) {
      final name = await _showNameDialog(context);
      if (name == null || !context.mounted) return;
      try {
        await Api.updateDisplayName(name);
      } catch (_) {}
      if (!context.mounted) return;
      context.read<AppState>().setDisplayName(name);
    }

    if (!onboarded && context.mounted) {
      final ok = await _showPermissionDialog(context);
      if (ok == true) {
        prefs.setBool(StorageKeys.onboardingDone, true);
      }
    }
  }

  static Future<String?> _showNameDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final theme = context.read<ThemeState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.92, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: scale,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.gold.withAlpha(60)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '欢迎来到拾晴日记',
                    style: XqTypography.headlineMedium.copyWith(
                      color: theme.gold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '先给自己起一个名字吧～',
                    style: XqTypography.bodyMedium.copyWith(
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: XqTypography.bodyLarge.copyWith(color: theme.textPrimary),
                    textAlign: TextAlign.center,
                    cursorColor: theme.gold,
                    decoration: InputDecoration(
                      hintText: '给自己取个名字吧',
                      hintStyle: TextStyle(
                        color: theme.textSecondary.withAlpha(120),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.gold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = ctrl.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx, name);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.gold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '确定',
                        style: XqTypography.headlineSmall.copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool?> _showPermissionDialog(BuildContext context) {
    final theme = context.read<ThemeState>();

    final permissions = [
      {
        'icon': Icons.location_on_outlined,
        'title': '定位',
        'desc': '看看你窗外的天气，不用手动选城市',
      },
      {
        'icon': Icons.photo_library_outlined,
        'title': '相册',
        'desc': '上传心情照片——照片只存在你的手机本地，不上传服务器',
      },
      {
        'icon': Icons.notifications_outlined,
        'title': '通知',
        'desc': '时光胶囊到期时通知你',
      },
      {'icon': Icons.folder_outlined, 'title': '存储', 'desc': '保存天气心情卡和限定壁纸到本地'},
    ];

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.92, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: scale,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.gold.withAlpha(60)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      '为了更好地陪伴你',
                      style: XqTypography.headlineMedium.copyWith(
                        color: theme.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '你的情绪数据只属于你自己',
                      style: XqTypography.bodySmall.copyWith(
                        color: theme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...permissions.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final p = entry.value;
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 300 + index * 100),
                        curve: Curves.easeOutCubic,
                        builder: (context, opacity, child) {
                          return AnimatedOpacity(
                            opacity: opacity,
                            duration: const Duration(milliseconds: 300),
                            child: child,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                p['icon'] as IconData,
                                size: 22,
                                color: theme.gold,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['title'] as String,
                                      style: XqTypography.bodyLarge.copyWith(
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p['desc'] as String,
                                      style: XqTypography.bodySmall.copyWith(
                                        color: theme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.gold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '我知道了',
                        style: XqTypography.headlineSmall.copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
