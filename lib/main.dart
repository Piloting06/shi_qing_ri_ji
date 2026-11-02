import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stores/app_state.dart';
import 'stores/theme_state.dart';
import 'stores/map_state.dart';
import 'theme/xq_theme.dart';
import 'widgets/splash_screen.dart';
import 'pages/login_page.dart';
import 'widgets/main_scaffold.dart';
import 'constants/keys.dart';
import 'api/api_client.dart';
import 'services/notification_service.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.bindNavigatorKey(appNavigatorKey);
  unawaited(NotificationService.initialize());
  Api.onUnauthorized = () {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null) return;
      ctx.read<AppState>().setLockedOut(true);
    });
  };
  Api.onAuthenticated = () {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    ctx.read<AppState>().setLockedOut(false);
  };
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  runApp(const XinQingRiJiApp());
}

class XinQingRiJiApp extends StatelessWidget {
  const XinQingRiJiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => ThemeState()),
        ChangeNotifierProvider(create: (_) => MapState()),
      ],
      child: Consumer<ThemeState>(
        builder: (context, theme, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: '拾晴日记',
            debugShowCheckedModeBanner: false,
            theme: XqTheme.forMode(theme.themeMode),
            darkTheme: XqTheme.forMode(theme.isDark ? theme.themeMode : 'dark'),
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            // 主题切换时全 App 颜色平滑过渡，避免生硬跳变
            themeAnimationDuration: const Duration(milliseconds: 420),
            themeAnimationCurve: Curves.easeOutCubic,
            home: const SplashGate(),
          );
        },
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(StorageKeys.token) ?? '';
    final dn = prefs.getString(StorageKeys.displayName) ?? '';
    if (!mounted) return;
    context.read<AppState>().setDisplayName(dn);
    final w = MediaQuery.sizeOf(context).width;
    context.read<AppState>().setWindowWidth(w.toInt());
    setState(() => _ready = true);
  }

  Route<void> _softEntryRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _onSplashComplete() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      _softEntryRoute(
        _token.isNotEmpty ? const MainScaffold() : const LoginPage(),
      ),
    );
    if (_token.isNotEmpty) {
      NotificationService.openPendingCapsuleIfAny(appNavigatorKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBF7F0),
        body: Center(child: SizedBox.shrink()),
      );
    }
    return InkSplashScreen(onComplete: _onSplashComplete);
  }
}
