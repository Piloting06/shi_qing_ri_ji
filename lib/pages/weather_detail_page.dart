import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
import '../utils/weather_utils.dart';
import '../widgets/weather_card_carousel.dart';
import '../widgets/weather_feedback_bar.dart';
import '../widgets/weather_illustration.dart';

enum WeatherDetailAction { relocate, chooseCity }

class WeatherDetailPage extends StatefulWidget {
  final Map<String, dynamic> weather;
  final String cityName;
  final String locationStatus;
  final DateTime? updatedAt;

  const WeatherDetailPage({
    super.key,
    required this.weather,
    required this.cityName,
    required this.locationStatus,
    required this.updatedAt,
  });

  @override
  State<WeatherDetailPage> createState() => _WeatherDetailPageState();
}

class _WeatherDetailPageState extends State<WeatherDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  int? _expandedMetric; // 0=体感, 1=湿度, 2=风速

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final current = weatherCurrent(widget.weather);
    final today = weatherDay(widget.weather);
    final tomorrow = weatherDay(widget.weather, key: 'tomorrow', index: 1);
    final dayAfter = weatherDay(widget.weather, key: 'day_after', index: 2);
    final weatherText =
        (current['weather'] ?? today['weather'] ?? '未知天气').toString();
    final code = weatherInt(current['weather_code']) ??
        weatherInt(today['weather_code']) ??
        0;
    final currentTemp =
        weatherInt(current['temp_current']) ?? weatherInt(today['temp_current']);
    final high = weatherInt(today['temp_max']);
    final low = weatherInt(today['temp_min']);
    final humidity =
        weatherInt(current['humidity']) ?? weatherInt(today['humidity']);
    final feelsLike = weatherInt(current['feels_like']);
    final wind =
        weatherInt(current['wind_current']) ?? weatherInt(today['wind']);
    final rain = weatherInt(today['rain_prob']);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // App bar
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: theme.textPrimary,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    '今天天气',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),

            // Hero card — stagger item 0
            _staggerChild(
              0,
              Container(
                padding: const EdgeInsets.all(18),
                decoration: XqDecorations.heroCard(
                  theme.isDark ? theme.cardColor : theme.cardElevated,
                  theme.isDark ? theme.cardElevated : theme.cardColor,
                  theme.borderColor,
                  dark: theme.isDark,
                  glow: theme.accentColor,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.cityName.isEmpty
                                    ? '当前位置'
                                    : widget.cityName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.locationStatus} · ${weatherUpdatedText(widget.updatedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: theme.textTertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                weatherText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        currentTemp == null
                                            ? '--°'
                                            : '$currentTemp°',
                                        style: TextStyle(
                                          color: theme.textPrimary,
                                          fontSize: 52,
                                          height: 1,
                                          fontWeight: FontWeight.w300,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Text(
                                      '${low == null ? '--' : '$low°'} / ${high == null ? '--' : '$high°'}',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 13,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (feelsLike != null)
                                    _badge(theme, '体感 $feelsLike°'),
                                  if (humidity != null)
                                    _badge(theme, '湿度 $humidity%'),
                                  if (wind != null)
                                    _badge(theme, '风速 $wind'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 118,
                          height: 112,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withAlpha(
                              theme.isDark ? 145 : 175,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.borderColor.withAlpha(80),
                            ),
                          ),
                          child: Center(
                            child: AnimatedWeatherIllustration(
                              code: code,
                              inkColor: theme.ink,
                              accentColor: theme.gold,
                              size: const Size(102, 74),
                              isNight: _isNight(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(
                              context,
                              WeatherDetailAction.relocate,
                            ),
                            icon: const Icon(Icons.my_location, size: 17),
                            label: const Text('重新定位'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.accentColor,
                              side: BorderSide(
                                color: theme.accentColor.withAlpha(90),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(
                              context,
                              WeatherDetailAction.chooseCity,
                            ),
                            icon: const Icon(Icons.search, size: 17),
                            label: const Text('手动城市'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.gold,
                              side: BorderSide(
                                  color: theme.gold.withAlpha(90)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3-day forecast — stagger item 1
            if (tomorrow.isNotEmpty || dayAfter.isNotEmpty)
              _staggerChild(
                1,
                WeatherCardCarousel(
                  days: [
                    if (tomorrow.isNotEmpty) tomorrow,
                    if (dayAfter.isNotEmpty) dayAfter,
                  ],
                  cityName: widget.cityName,
                  todayHigh: high,
                ),
              ),
            const SizedBox(height: 18),

            // "现在感受" header — stagger item 2
            _staggerChild(
              2,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '现在感受',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          theme,
                          0,
                          Icons.device_thermostat_outlined,
                          '体感温度',
                          feelsLike == null ? '暂无' : '$feelsLike°',
                          feelsLike != null
                              ? '体感\$feelsLike°是因为湿度较高，实际温度可能是\$currentTemp°'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricCard(
                          theme,
                          1,
                          Icons.water_drop_outlined,
                          '空气湿度',
                          humidity == null ? '暂无' : '$humidity%',
                          humidity != null
                              ? humidity > 70
                                  ? '湿度较高，体感可能会闷热'
                                  : humidity < 30
                                      ? '空气偏干，注意补水'
                                      : '湿度适中，比较舒适'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricCard(
                          theme,
                          2,
                          Icons.air,
                          '今日风速',
                          wind == null ? '暂无' : '$wind km/h',
                          wind != null
                              ? wind > 30
                                  ? '风力较大，外出注意安全'
                                  : wind > 15
                                      ? '有风，体感会比实际温度凉一些'
                                      : '微风，适合户外活动'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Rain probability — stagger item 3
            if (rain != null)
              _staggerChild(
                3,
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _rainCard(theme, rain),
                ),
              ),
            const SizedBox(height: 20),

            // Feedback bar — stagger item 4
            _staggerChild(
              4,
              WeatherFeedbackBar(
                weatherText: weatherText,
                currentTemp: currentTemp,
                high: high,
                low: low,
                cityName: widget.cityName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stagger Animation ──

  bool _isNight() {
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 19;
  }

  Widget _staggerChild(int index, Widget child) {
    final start = index * 0.1;
    final end = (start + 0.3).clamp(0.0, 1.0);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        )),
        child: child,
      ),
    );
  }

  // ── Metric Card (with expand) ──

  Widget _metricCard(
    ThemeState theme,
    int index,
    IconData icon,
    String label,
    String value,
    String? detail,
  ) {
    final expanded = _expandedMetric == index;
    return GestureDetector(
      onTap: detail != null
          ? () {
              HapticFeedback.selectionClick();
              setState(() => _expandedMetric = expanded ? null : index);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
          border: Border.all(
            color: expanded
                ? theme.accentColor.withAlpha(80)
                : theme.borderColor,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.accentColor, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              AnimatedCrossFade(
                firstChild: Icon(
                  Icons.expand_more,
                  size: 14,
                  color: theme.textTertiary,
                ),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Rain Probability Card with progress ring ──

  Widget _rainCard(ThemeState theme, int rain) {
    final isHigh = rain >= 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        children: [
          // Progress ring
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 3,
                  color: theme.borderColor.withAlpha(60),
                ),
                // Progress arc
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: rain / 100),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      color: isHigh
                          ? theme.accentColor
                          : theme.accentColor.withAlpha(140),
                    );
                  },
                ),
                // Percentage text
                Text(
                  '$rain%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isHigh ? theme.accentColor : theme.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHigh
                  ? '今天大概率会下雨，出门记得带伞。'
                  : rain >= 30
                      ? '有一定概率降水，出门前可以看一眼天空。'
                      : '今天基本不会下雨，放心出门吧。',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(ThemeState theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
