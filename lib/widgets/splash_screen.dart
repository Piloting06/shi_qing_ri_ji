import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import 'weather_sky.dart';
import 'xq/xq_kit.dart';

/// 启动：一张空笺上，晴天按版序套印显影（浅色晴昼、深色晴夜），书名浮现，最后钤一枚「拾」。
/// 1500ms；只动 opacity/transform；减弱动效时直接呈现终态。
class InkSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const InkSplashScreen({super.key, required this.onComplete});

  @override
  State<InkSplashScreen> createState() => _InkSplashScreenState();
}

class _InkSplashScreenState extends State<InkSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            widget.onComplete();
          }
        });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _phase(double start, double end) {
    if (MediaQuery.of(context).disableAnimations) return 1;
    final t = ((_ctrl.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutQuart.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final palette = SkyPalette.of(
      SkyCondition.clear,
      theme.isDark ? SkyTime.night : SkyTime.day,
    );
    final sky = WeatherSkyScene(
      palette: palette,
      condition: SkyCondition.clear,
      paper: theme.backgroundColor,
      seed: 3,
      fade: true,
      reveal: true,
      motif: skyMotifFor(SkyCondition.clear),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.darkText ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: AnimatedBuilder(
          animation: _ctrl,
          child: sky,
          builder: (context, skyChild) {
            final title = _phase(0.35, 0.65);
            final line = _phase(0.5, 0.8);
            final stamp = _phase(0.72, 0.9);
            return Stack(
              fit: StackFit.expand,
              children: [
                ?skyChild,
                Align(
                  alignment: const Alignment(0, -0.32),
                  child: Opacity(
                    opacity: title,
                    child: Transform.translate(
                      offset: Offset(0, (1 - title) * 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: stamp,
                            child: Transform.scale(
                              scale: 1.5 - 0.5 * stamp,
                              child: XqSeal(
                                char: '拾',
                                color: theme.sealColor,
                                size: 50,
                                style: XqSealStyle.bai,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '拾晴日记',
                            style: XqTypography.splashTitle.copyWith(
                              color: palette.onSky,
                              fontSize: 32,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Opacity(
                            opacity: line,
                            child: Text(
                              '天气加心情。写下来，发给 Ta。',
                              style: TextStyle(
                                color: palette.onSkySoft,
                                fontSize: 13,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
