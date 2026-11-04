import 'package:flutter/material.dart';
import '../theme/xq_typography.dart';
import 'xq/xq_kit.dart';
import 'xq/xq_paper.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../services/notification_service.dart';
import '../stores/theme_state.dart';
import '../theme/xq_colors.dart';
import '../stores/app_state.dart';
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
  // 访问过的 Tab 常驻（Offstage 保活，不再销毁重建、不再重复拉数据）
  final _visited = <int>{};
  bool _onboardingChecked = false;
  bool _lockoutHandled = false;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _visited.add(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_onboardingChecked && mounted) {
        _onboardingChecked = true;
        OnboardingFlow.checkAndShow(context);
      }
      _rescheduleCapsuleReminders();
    });
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
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = i;
      _visited.add(i);
    });
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
          const SnackBar(content: Text('登录已过期，请重新登录')),
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
              // 切 Tab：只淡入当前页（160ms），其余页 Offstage 保活、暂停动画、不参与绘制
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final (i, page) in const [
                    HomePage(),
                    MoodPage(),
                    CityMapPage(),
                    ProfilePage(),
                  ].indexed)
                    if (_visited.contains(i))
                      _TabSlot(key: ValueKey(i), active: i == _currentIndex, child: page),
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
  'sujian' => XqColors.sujianCard, // 素笺通栏 surface
  'sujian_dark' => XqColors.sujianDarkCard,
  'warm' => const Color(0xFFFAF4EC),
  'dark' => const Color(0xFF0E1222),
  'mint' => const Color(0xFFDDEBE3),
  'blush' => const Color(0xFFF2DED8),
  _ => XqColors.sujianCard,
};

/// 笺谱底栏：贴底纸条 + 顶部一道乌丝栏；四个单字「天 · 心 · 城 · 我」（展示体），
/// 选中的那个变成一枚墨色白文小印（朱砂留给内容里的印）。遵守系统减弱动效。
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
  static const _chars = ['天', '心', '城', '我'];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          image: XqPaper.grain(theme.paperFiber, strength: theme.isDark ? 0.6 : 0.8),
          border: Border(top: BorderSide(color: theme.frameColor, width: 0.6)),
        ),
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(4, (i) {
              final active = i == currentIndex;
              return Expanded(
                child: Semantics(
                  label: _labels[i],
                  button: true,
                  selected: active,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: reduce ? 0 : 180),
                        switchInCurve: Curves.easeOutQuart,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween(begin: 1.18, end: 1.0).animate(anim),
                            child: child,
                          ),
                        ),
                        child: active
                            ? XqSeal(
                                key: ValueKey('on$i'),
                                char: _chars[i],
                                color: theme.accentColor,
                                size: 34,
                                style: XqSealStyle.bai,
                                angle: i.isEven ? -0.04 : 0.04,
                              )
                            : SizedBox(
                                key: ValueKey('off$i'),
                                width: 34,
                                height: 34,
                                child: Center(
                                  child: Text(
                                    _chars[i],
                                    style: XqTypography.headlineSmall.copyWith(
                                      color: theme.textTertiary,
                                      fontSize: 20,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// 一个 Tab 的槽位：当前页淡入；离开后淡出完毕即 Offstage（保留状态，不绘制、不跑动画）
class _TabSlot extends StatefulWidget {
  final bool active;
  final Widget child;

  const _TabSlot({super.key, required this.active, required this.child});

  @override
  State<_TabSlot> createState() => _TabSlotState();
}

class _TabSlotState extends State<_TabSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: widget.active ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  @override
  void didUpdateWidget(_TabSlot old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = widget.active ? 1 : 0;
    } else if (widget.active) {
      _fade.forward();
    } else {
      // 离开的页立即让出：不做淡出，避免两页同时绘制
      _fade.value = 0;
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = !widget.active && _fade.isDismissed;
    return Offstage(
      offstage: hidden,
      child: TickerMode(
        enabled: widget.active,
        child: IgnorePointer(
          ignoring: !widget.active,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOutQuart),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
