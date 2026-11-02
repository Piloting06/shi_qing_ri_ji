import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../services/notification_service.dart';
import '../stores/theme_state.dart';
import '../stores/app_state.dart';
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

    final bottomInsets = MediaQuery.of(context).padding.bottom;

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
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.exit_to_app_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    '再按一次退出',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              backgroundColor: theme.textPrimary.withAlpha(160),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: EdgeInsets.fromLTRB(
                80, 0, 80, 16 + MediaQuery.of(context).padding.bottom,
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(child: Container(color: theme.backgroundColor)),
            Padding(
              padding: EdgeInsets.only(bottom: 70 + bottomInsets),
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
              Positioned.fill(
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
            Positioned(
              bottom: 6 + bottomInsets,
              left: 0,
              right: 0,
              child: Center(
                child: _FrostedCapsule(
                  currentIndex: _currentIndex,
                  theme: theme,
                  onTap: _onTabTap,
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

/// 系统导航栏颜色 — 匹配页面背景（胶囊半透明，底部统一）
Color _navBarColor(String theme) => switch (theme) {
  'warm' => const Color(0xFFFAF4EC),
  'dark' => const Color(0xFF0E1222),
  'mint' => const Color(0xFFDDEBE3),
  'blush' => const Color(0xFFF2DED8),
  _ => const Color(0xFFFAF4EC),
};

/// 毛玻璃悬浮胶囊导航栏
class _FrostedCapsule extends StatefulWidget {
  final int currentIndex;
  final ThemeState theme;
  final Function(int) onTap;

  const _FrostedCapsule({
    required this.currentIndex,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_FrostedCapsule> createState() => _FrostedCapsuleState();
}

class _FrostedCapsuleState extends State<_FrostedCapsule>
    with TickerProviderStateMixin {
  static const _icons = [
    _TabIcon(Icons.wb_sunny_outlined, Icons.wb_sunny),
    _TabIcon(Icons.favorite_border, Icons.favorite),
    _TabIcon(Icons.explore_outlined, Icons.explore),
    _TabIcon(Icons.person_outline, Icons.person),
  ];
  static const _labels = ['天气', '心情', '城迹', '我的'];
  static const _tabWidth = 64.0;
  static const _hPadding = 20.0;
  static const _capsuleHeight = 72.0;
  static const _capsuleWidth = _tabWidth * 4 + _hPadding * 2; // 296

  // Bounce
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceTranslate;

  // Light glow
  late final AnimationController _glowCtrl;
  late final AnimationController _breatheCtrl;
  late final AnimationController _rippleCtrl;
  late final Animation<double> _rippleRadiusAnim;
  late final Animation<double> _rippleAlphaAnim;
  double _glowX = 0;
  double _touchAlpha = 0;
  bool _isTouching = false;

  /// Tab 中心 x 坐标 — 4 个 Tab 等分胶囊宽度
  double _tabCenterX(int index) => (index + 0.5) * _capsuleWidth / 4;

  /// 四主题浅色磨砂胶囊底 — 半透明融入页面，彩色光效在上方清晰可见
  static Color _capsuleBg(String theme) => switch (theme) {
    'warm' => const Color(0xE6F5EDE0),  // 暖调磨砂奶白
    'dark' => const Color(0xDD2E3350),  // 深蓝磨砂（暗主题仍需深色底）
    'mint' => const Color(0xE6EEF6F0),  // 薄荷磨砂
    'blush' => const Color(0xE6F6EAEB), // 豆沙磨砂
    _ => const Color(0xE6F5EDE0),
  };

  @override
  void initState() {
    super.initState();
    _glowX = _tabCenterX(widget.currentIndex);

    // Bounce on tap — 优雅幅度: -7px 弹起 → +2px 回弹
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceTranslate = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 0.3),
      TweenSequenceItem(tween: Tween(begin: -7, end: 2), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 0.2),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));

    // Glow return animation (finger up → active tab)
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _glowCtrl.addListener(() {
      if (_glowCtrl.isAnimating) {
        setState(() => _glowX = _glowAnim!.value);
      }
    });

    // Breathing ambient glow
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Ripple on tap — 扩散波纹 300ms
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _rippleRadiusAnim = Tween<double>(begin: 5, end: 100).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOutCubic),
    );
    _rippleAlphaAnim = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
  }

  Animation<double>? _glowAnim;

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _glowCtrl.dispose();
    _breatheCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FrostedCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isTouching) {
      final target = _tabCenterX(widget.currentIndex);
      _glowAnim = Tween<double>(begin: _glowX, end: target).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOutCubic),
      );
      _touchAlpha = 0;
      _glowCtrl.forward(from: 0);
      // 切换 Tab 时在新位置触发波纹 + 触觉
      _glowX = target;
      _rippleCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  void _onCapsuleTap() {
    if (_bounceCtrl.isAnimating) return;
    // 强触觉反馈 + 波纹扩散
    HapticFeedback.mediumImpact();
    _bounceCtrl.forward(from: 0);
    _rippleCtrl.forward(from: 0);
  }

  void _onPointerDown(PointerDownEvent event) {
    HapticFeedback.lightImpact();
    setState(() {
      _isTouching = true;
      _glowX = event.localPosition.dx;
      _touchAlpha = 90;
    });
    _glowCtrl.stop();
  }

  void _onPointerMove(PointerMoveEvent event) {
    setState(() => _glowX = event.localPosition.dx);
  }

  void _onPointerUp(PointerUpEvent event) {
    final target = _tabCenterX(widget.currentIndex);
    _glowAnim = Tween<double>(begin: _glowX, end: target).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOutCubic),
    );
    setState(() {
      _isTouching = false;
      _touchAlpha = 0;
    });
    _glowCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final animActive = context.watch<AppState>().animActive;

    return AnimatedBuilder(
      animation: _bounceCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _bounceTranslate.value),
        child: child,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onCapsuleTap,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: _capsuleWidth,
              height: _capsuleHeight,
              decoration: BoxDecoration(
                color: _capsuleBg(t.themeMode),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: t.accentColor.withAlpha(80),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Light glow layer — 仅在 animActive 时渲染
                  if (animActive)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_breatheCtrl, _rippleCtrl]),
                        builder: (context, _) => CustomPaint(
                          painter: _LightGlowPainter(
                            glowX: _glowX,
                            touchAlpha: _touchAlpha,
                            breatheAlpha: 60 + _breatheCtrl.value * 60,
                            activeIndex: widget.currentIndex,
                            accentColor: t.accentColor,
                            height: _capsuleHeight,
                            rippleRadius: _rippleRadiusAnim.value,
                            rippleAlpha: _rippleAlphaAnim.value,
                          ),
                        ),
                      ),
                    ),
                  // Tab content — Expanded 等分宽度，与 Painter 坐标对齐
                  RepaintBoundary(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_icons.length, (i) {
                        final active = widget.currentIndex == i;
                        return Expanded(
                          child: _CapsuleTabItem(
                            icon: _icons[i],
                            label: _labels[i],
                            active: active,
                            accentColor: t.accentLight,
                            inactiveColor: t.textPrimary.withAlpha(130),
                            onTap: () => widget.onTap(i),
                          ),
                        );
                      }),
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
}

class _TabIcon {
  final IconData outlined;
  final IconData filled;
  const _TabIcon(this.outlined, this.filled);
}

/// 动感光效画笔 — 浅色磨砂底 + 彩色主题光效
/// 三层：呼吸光晕 → 触摸追踪光 → 点击扩散波纹
/// 全部使用主题强调色，与磨砂胶囊融为一体
class _LightGlowPainter extends CustomPainter {
  final double glowX;
  final double touchAlpha;
  final double breatheAlpha;
  final int activeIndex;
  final Color accentColor;
  final double height;
  final double rippleRadius;
  final double rippleAlpha;

  _LightGlowPainter({
    required this.glowX,
    required this.touchAlpha,
    required this.breatheAlpha,
    required this.activeIndex,
    required this.accentColor,
    required this.height,
    this.rippleRadius = 0,
    this.rippleAlpha = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = height / 2;
    final tabZone = size.width / 4;
    final activeX = (activeIndex + 0.5) * tabZone;

    // ── Layer 1: 彩色呼吸光晕（圆形绘制，精准居中） ──
    canvas.drawCircle(
      Offset(activeX, centerY),
      50,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accentColor.withAlpha(breatheAlpha.round()),
            accentColor.withAlpha((breatheAlpha * 0.4).round()),
            accentColor.withAlpha(0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(activeX, centerY),
          radius: 50,
        )),
    );

    // ── Layer 1.5: 选中 Tab 高亮核心 ──
    final coreAlpha = (breatheAlpha * 1.2).round().clamp(0, 200);
    canvas.drawCircle(
      Offset(activeX, centerY),
      30,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accentColor.withAlpha(coreAlpha),
            accentColor.withAlpha(0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(activeX, centerY),
          radius: 30,
        )),
    );

    // ── Layer 2: 触摸追踪光 ──
    if (touchAlpha > 1) {
      canvas.drawCircle(
        Offset(glowX, centerY),
        55,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accentColor.withAlpha(
                  (touchAlpha * 1.4).round().clamp(0, 200)),
              accentColor.withAlpha((touchAlpha * 0.5).round()),
              accentColor.withAlpha(0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(
            center: Offset(glowX, centerY),
            radius: 55,
          )),
      );
    }

    // ── Layer 3: 点击扩散波纹 ──
    if (rippleAlpha > 1 && rippleRadius > 0) {
      final clamped = math.min(rippleRadius, size.width);
      final ringWidth = 18.0;
      final inner = (clamped - ringWidth).clamp(0.0, size.width);
      canvas.drawCircle(
        Offset(glowX, centerY),
        clamped,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accentColor.withAlpha(0),
              if (inner > 0)
                accentColor.withAlpha(0)
              else
                accentColor.withAlpha(rippleAlpha.round()),
              accentColor.withAlpha(rippleAlpha.round()),
              accentColor.withAlpha(0),
            ],
            stops: inner > 0
                ? [0.0, inner / clamped, 0.85, 1.0]
                : const [0.0, 0.0, 0.7, 1.0],
          ).createShader(Rect.fromCircle(
            center: Offset(glowX, centerY),
            radius: clamped,
          )),
      );
    }
  }

  @override
  bool shouldRepaint(_LightGlowPainter old) =>
      old.glowX != glowX ||
      old.touchAlpha != touchAlpha ||
      old.breatheAlpha != breatheAlpha ||
      old.activeIndex != activeIndex ||
      old.accentColor != accentColor ||
      old.height != height ||
      old.rippleRadius != rippleRadius ||
      old.rippleAlpha != rippleAlpha;
}

class _CapsuleTabItem extends StatelessWidget {
  final _TabIcon icon;
  final String label;
  final bool active;
  final Color accentColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _CapsuleTabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.accentColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? accentColor : inactiveColor;

    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 素笺规范：当前项用 accent 文字 + 2px 细线，不用色块
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: active ? 16 : 0,
                height: 2,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: active ? accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Icon(
                  icon.outlined,
                  key: ValueKey('${label}_$active'),
                  size: 21,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
