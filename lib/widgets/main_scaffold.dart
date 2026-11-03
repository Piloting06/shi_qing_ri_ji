import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../services/notification_service.dart';
import '../stores/theme_state.dart';
import '../stores/app_state.dart';
import '../widgets/xq/xq_icons.dart';
import '../widgets/xq_toast.dart';
import '../pages/home_page.dart';
import '../pages/mood_page.dart';
import '../pages/city_map_page.dart';
import '../pages/profile_page.dart';
import '../pages/login_page.dart';
import 'onboarding_flow.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({super.key, this.initialIndex = 0});

  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainScaffoldState>();
    state?.goToTab(index);
  }

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;
  late final PageController _pageController;
  bool _onboardingChecked = false;
  bool _lockoutHandled = false;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_onboardingChecked && mounted) {
        _onboardingChecked = true;
        OnboardingFlow.checkAndShow(context);
      }
      _rescheduleCapsuleReminders();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _rescheduleCapsuleReminders() async {
    try {
      final data = await Api.getCapsuleList();
      final capsules = data['capsules'] as List? ?? [];
      for (final c in capsules) {
        if (c is! Map) continue;
        if (c['is_opened'] == 1) continue;
        final id = c['id'];
        final openDate = c['open_date']?.toString();
        final content = c['content']?.toString() ?? '';
        if (id == null || openDate == null) continue;
        await NotificationService.scheduleCapsuleReminder(
          capsuleId: id is int ? id : int.tryParse(id.toString()) ?? 0,
          openDate: openDate,
          preview: content.length > 36
              ? '${content.substring(0, 36)}...'
              : content,
        );
      }
    } catch (_) {}
  }

  void goToTab(int i) {
    if (_currentIndex == i) return;
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _currentIndex = i);
  }

  void _onTabTap(int i) {
    if (_currentIndex == i) return;
    goToTab(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final appState = context.watch<AppState>();

    final overlayStyle = SystemUiOverlayStyle(
      systemNavigationBarColor: _navBarColor(theme.themeMode),
      systemNavigationBarDividerColor: _navBarColor(theme.themeMode),
      systemNavigationBarIconBrightness:
          theme.isDark ? Brightness.light : Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: theme.isDark
          ? Brightness.light
          : Brightness.dark,
    );

    if (appState.isLockedOut && !_lockoutHandled) {
      _lockoutHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('登录过期了，重新登一下吧')),
        );
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 不在首页 tab → 切回首页
        if (_currentIndex != 0) {
          goToTab(0);
          return;
        }
        // 在首页 → 双击返回退出
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          XqToast.info(context, '再按一次退出');
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                children: const [
                  HomePage(),
                  MoodPage(),
                  CityMapPage(),
                  ProfilePage(),
                ],
              ),
            ),
            if (theme.transitioning)
              SizedBox(
                height: 2,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 0.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Container(
                      color: theme.accentColor.withAlpha((value * 120).round()),
                    ),
                  ),
                ),
              ),
            // 素笺贴底通栏：surface 底 + 顶部 1px 线，无毛玻璃无光晕
            _SujianBottomBar(
              currentIndex: _currentIndex,
              theme: theme,
              onTap: _onTabTap,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// 系统导航栏颜色 — 匹配页面背景（胶囊半透明，底部统一）
Color _navBarColor(String theme) => switch (theme) {
  'sujian' => const Color(0xFFF7F7F2), // 素笺通栏 surface
  'sujian_dark' => const Color(0xFF1B1F21),
  'warm' => const Color(0xFFFAF4EC),
  'dark' => const Color(0xFF0E1222),
  'mint' => const Color(0xFFDDEBE3),
  'blush' => const Color(0xFFF2DED8),
  _ => const Color(0xFFF7F7F2),
};

/// 素笺贴底通栏导航：surface 底、顶部 1px 线、选中项 accent + 2px 顶线。
/// 无毛玻璃、无光晕、无循环动画；遵守系统减弱动效。
class _SujianBottomBar extends StatelessWidget {
  final int currentIndex;
  final ThemeState theme;
  final Function(int) onTap;

  const _SujianBottomBar({
    required this.currentIndex,
    required this.theme,
    required this.onTap,
  });

  static const _labels = ['天气', '心情', '城迹', '我的'];
  static const _icons = [
    XqIcons.sunny,
    XqIcons.heart,
    XqIcons.compass,
    XqIcons.person,
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Semantics(
      container: true,
      child: Container(
        // 系统导航栏区域同色，视觉与通栏一体
        color: theme.cardColor,
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 0.8, color: theme.borderColor),
            SizedBox(
              height: 56,
              child: Row(
                children: List.generate(4, (i) {
                  final active = i == currentIndex;
                  final color = active ? theme.accentColor : theme.textTertiary;
                  return Expanded(
                    child: Semantics(
                      label: _labels[i],
                      button: true,
                      selected: active,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 素笺规范：选中项 2px 顶线
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              width: active ? 16 : 0,
                              height: 2,
                              margin: const EdgeInsets.only(bottom: 3),
                              decoration: BoxDecoration(
                                color: active
                                    ? theme.accentColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            XqIcon(_icons[i], size: 21, color: color),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              // 继承主题标签样式（只覆盖色与字重），防止回退到无主题字体
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(
                                    fontSize: 11,
                                    letterSpacing: 1,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: color,
                                  ),
                              child: Text(_labels[i]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
