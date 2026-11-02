import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/city_intro_data.dart';
import '../stores/map_state.dart';
import '../stores/theme_state.dart';

class CityIntroCard extends StatefulWidget {
  final CityData city;
  final CityIntro intro;
  final int? footCount;

  const CityIntroCard({
    super.key,
    required this.city,
    required this.intro,
    this.footCount,
  });

  static void show(BuildContext context, CityData city, int? footCount) {
    final intro = CityIntroData.get(city.code);
    if (intro == null) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'city-intro',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (_, _, _) =>
          CityIntroCard(city: city, intro: intro, footCount: footCount),
    );
  }

  @override
  State<CityIntroCard> createState() => _CityIntroCardState();
}

class _CityIntroCardState extends State<CityIntroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  static const _themes = [
    _CityTheme(
      primary: Color(0xFFD4775B),
      light: Color(0xFFF5E6E0),
      icon: Icons.local_fire_department,
    ),
    _CityTheme(
      primary: Color(0xFF6B9DAD),
      light: Color(0xFFE0EEF2),
      icon: Icons.water,
    ),
    _CityTheme(
      primary: Color(0xFF5B8A72),
      light: Color(0xFFE5EDE8),
      icon: Icons.auto_stories,
    ),
    _CityTheme(
      primary: Color(0xFF9B7EC8),
      light: Color(0xFFEDE6F5),
      icon: Icons.nightlife,
    ),
    _CityTheme(
      primary: Color(0xFF8EACC1),
      light: Color(0xFFE3EDF3),
      icon: Icons.ac_unit,
    ),
    _CityTheme(
      primary: Color(0xFFC4A44A),
      light: Color(0xFFF0EBD8),
      icon: Icons.grass,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final intro = widget.intro;
    final ct = _themes[intro.themeIndex.clamp(0, 5)];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: ct.primary.withAlpha(40),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── 色带区 ──
                  AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, _) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ct.primary.withAlpha(
                                180 + (_shimmerCtrl.value * 40).round()),
                            ct.primary.withAlpha(
                                140 + (_shimmerCtrl.value * 30).round()),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(ct.icon, color: Colors.white.withAlpha(180),
                              size: 24),
                          const SizedBox(height: 8),
                          Text(
                            widget.city.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            intro.vibe,
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 正文区 ──
                  Container(
                    width: double.infinity,
                    color: theme.cardColor,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // intro
                        Text(
                          intro.intro,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15,
                            height: 1.8,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // funFact
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: ct.light,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 16, color: ct.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  intro.funFact,
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // tags
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: intro.tags
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: ct.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: ct.primary.withAlpha(40),
                                          width: 0.5),
                                    ),
                                    child: Text(
                                      t,
                                      style: TextStyle(
                                        color: ct.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),

                        // foot count
                        if (widget.footCount != null &&
                            widget.footCount! > 0) ...[
                          const SizedBox(height: 12),
                          Text(
                            '你在这座城市留过 ${widget.footCount} 条足迹',
                            style: TextStyle(
                              color: theme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── 关闭按钮 ──
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      color: theme.cardColor,
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Icon(Icons.keyboard_arrow_down,
                          color: theme.textTertiary, size: 28),
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

class _CityTheme {
  final Color primary;
  final Color light;
  final IconData icon;

  const _CityTheme({
    required this.primary,
    required this.light,
    required this.icon,
  });
}
