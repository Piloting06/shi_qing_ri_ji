import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';

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
          duration: const Duration(milliseconds: 1320),
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

  double _phase(double start, double end, Curve curve) {
    return curve.transform(
      ((_ctrl.value - start) / (end - start)).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final cloud = _phase(0.0, 0.36, Curves.easeOutCubic);
          final reveal = _phase(0.34, 0.66, Curves.easeOutCubic);
          final reveal2 = _phase(0.34 + 0.15, 0.66 + 0.15, Curves.easeOutCubic);
          final exit = _phase(0.80, 1.0, Curves.easeInCubic);
          final cardOpacity = (reveal * (1 - exit)).clamp(0.0, 1.0);
          final cardDy = (1 - reveal) * 12 - exit * 12;
          final titleScale = 0.92 + reveal * 0.02 - exit * 0.02;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Glow orbs matching auth backdrop style
              Positioned(
                top: -80,
                right: -70,
                child: _SplashGlow(
                  size: 220,
                  color: theme.accentColor.withAlpha(theme.isDark ? 42 : 30),
                  opacity: (1 - exit).clamp(0.0, 1.0),
                ),
              ),
              Positioned(
                left: -80,
                bottom: 80,
                child: _SplashGlow(
                  size: 180,
                  color: theme.gold.withAlpha(theme.isDark ? 30 : 24),
                  opacity: (1 - exit).clamp(0.0, 1.0),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.isDark
                        ? [
                            theme.backgroundColor,
                            theme.cardColor,
                            theme.backgroundColor,
                          ]
                        : [
                            theme.backgroundColor,
                            theme.cardElevated,
                            theme.backgroundColor,
                          ],
                  ),
                ),
              ),
              CustomPaint(
                painter: _InkCloudPainter(
                  theme: theme,
                  cloud: cloud,
                  reveal: reveal,
                  exit: exit,
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, cardDy),
                  child: Opacity(
                    opacity: cardOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _WeatherMark(theme: theme),
                        const SizedBox(height: 22),
                        Transform.scale(
                          scale: titleScale,
                          child: Text(
                            '拾晴日记',
                            style: XqTypography.splashTitle.copyWith(
                              color: theme.isDark
                                  ? theme.textPrimary
                                  : theme.gold,
                              letterSpacing: 5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '记录天气，也记录你',
                          style: XqTypography.bodySmall.copyWith(
                            color: theme.textSecondary.withAlpha(
                              (170 * reveal * (1 - exit)).round().clamp(0, 170),
                            ),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '每一座城市都有它的情绪',
                          style: XqTypography.labelSmall.copyWith(
                            color: theme.textTertiary.withAlpha(
                              (140 * reveal2 * (1 - exit)).round().clamp(0, 140),
                            ),
                            letterSpacing: 1,
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
    );
  }
}

class _WeatherMark extends StatelessWidget {
  final ThemeState theme;

  const _WeatherMark({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor.withAlpha(theme.isDark ? 230 : 245),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(theme.isDark ? 55 : 18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.gold.withAlpha(42),
                  border: Border.all(color: theme.gold.withAlpha(120)),
                ),
                child: Icon(
                  theme.isDark
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_outlined,
                  size: 14,
                  color: theme.gold,
                ),
              ),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          _Line(width: 70, color: theme.paperLine),
          const SizedBox(height: 7),
          _Line(width: 48, color: theme.paperLine),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final double width;
  final Color color;

  const _Line({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SplashGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SplashGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _InkCloudPainter extends CustomPainter {
  final ThemeState theme;
  final double cloud;
  final double reveal;
  final double exit;

  const _InkCloudPainter({
    required this.theme,
    required this.cloud,
    required this.reveal,
    required this.exit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 12);
    final lightAlpha = ((1 - exit) * 62).round().clamp(0, 62);
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              theme.gold.withAlpha(lightAlpha),
              theme.accentColor.withAlpha((lightAlpha * 0.45).round()),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: 150 + reveal * 30),
          );
    canvas.drawCircle(center, 150 + reveal * 30, glowPaint);

    final inkAlpha = ((1 - exit) * (theme.isDark ? 68 : 42)).round().clamp(
      0,
      80,
    );
    final inkPaint = Paint()
      ..color = theme.ink.withAlpha(inkAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    _blob(canvas, center, 58 + cloud * 118 + exit * 26, inkPaint, seed: 3);
    _blob(
      canvas,
      center + Offset(-46 - cloud * 18, 22 + cloud * 8),
      22 + cloud * 50 + exit * 16,
      inkPaint,
      seed: 7,
    );
    _blob(
      canvas,
      center + Offset(42 + cloud * 16, -28 - cloud * 6),
      18 + cloud * 42 + exit * 18,
      inkPaint,
      seed: 11,
    );
  }

  void _blob(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required int seed,
  }) {
    if (radius <= 0) return;
    final random = math.Random(seed);
    final path = Path();
    const count = 10;
    for (var i = 0; i <= count; i++) {
      final angle = i / count * math.pi * 2;
      final r = radius * (0.82 + random.nextDouble() * 0.28);
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        final prevAngle = (i - 0.5) / count * math.pi * 2;
        final cp =
            center +
            Offset(
              math.cos(prevAngle) * radius * (0.98 + random.nextDouble() * 0.2),
              math.sin(prevAngle) * radius * (0.98 + random.nextDouble() * 0.2),
            );
        path.quadraticBezierTo(cp.dx, cp.dy, point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InkCloudPainter oldDelegate) {
    return oldDelegate.cloud != cloud ||
        oldDelegate.reveal != reveal ||
        oldDelegate.exit != exit ||
        oldDelegate.theme != theme;
  }
}
