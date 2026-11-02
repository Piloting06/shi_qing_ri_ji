import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
import '../utils/weather_utils.dart';
import 'weather_illustration.dart';
import 'glow_wrap.dart';

class WeatherSummaryCard extends StatefulWidget {
  final bool loading;
  final bool refreshing;
  final String? statusText;
  final Map<String, dynamic>? weather;
  final String cityName;
  final String locationStatus;
  final DateTime? updatedAt;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onChooseCity;
  final VoidCallback onOpenDetail;

  const WeatherSummaryCard({
    super.key,
    required this.loading,
    this.refreshing = false,
    this.statusText,
    required this.weather,
    required this.cityName,
    required this.locationStatus,
    required this.updatedAt,
    required this.error,
    required this.onRetry,
    required this.onChooseCity,
    required this.onOpenDetail,
  });

  @override
  State<WeatherSummaryCard> createState() => _WeatherSummaryCardState();
}

class _WeatherSummaryCardState extends State<WeatherSummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  // Refresh flash state
  bool _showFlash = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WeatherSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect refresh ended → trigger flash
    if (oldWidget.refreshing && !widget.refreshing && !widget.loading) {
      setState(() => _showFlash = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _showFlash = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: widget.loading && widget.weather == null
          ? _buildSkeleton(theme)
          : widget.error != null && widget.weather == null
              ? _buildError(theme)
              : _buildWeather(theme),
    );
  }

  // ── Skeleton Shimmer Loading ──

  Widget _buildSkeleton(ThemeState theme) {
    return _shell(
      theme,
      child: AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-1.0 + _shimmerAnim.value, 0),
                end: Alignment(_shimmerAnim.value, 0),
                colors: [
                  theme.cardColor.withAlpha(0),
                  theme.accentColor.withAlpha(25),
                  theme.cardColor.withAlpha(0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // City name placeholder
                _shimmerBox(theme, width: 100, height: 21),
                const SizedBox(height: 6),
                _shimmerBox(theme, width: 70, height: 12),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Big temperature placeholder
                    _shimmerBox(theme, width: 80, height: 42),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(theme, width: 60, height: 12),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _shimmerPill(theme),
                            const SizedBox(width: 7),
                            _shimmerPill(theme),
                            const SizedBox(width: 7),
                            _shimmerPill(theme),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Prompt placeholder
                _shimmerBox(theme, width: double.infinity, height: 14),
                const SizedBox(height: 10),
                _shimmerBox(theme, width: 120, height: 11),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shimmerBox(ThemeState theme, {double? width, double height = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.borderColor.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _shimmerPill(ThemeState theme) {
    return Container(
      width: 48,
      height: 22,
      decoration: BoxDecoration(
        color: theme.borderColor.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  // ── Error State ──

  Widget _buildError(ThemeState theme) {
    return _shell(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_off_outlined, color: theme.errorColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.error ?? '天气加载失败',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '没关系，试试重新定位或选一个城市吧～',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('重新定位'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.accentColor,
                    side: BorderSide(color: theme.accentColor.withAlpha(90)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onChooseCity,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('手动选城市'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.gold,
                    side: BorderSide(color: theme.gold.withAlpha(90)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Weather Content ──

  String? _shortTime(String? v) {
    if (v == null || v.length < 5) return null;
    // 服务端可能给 "HH:mm" 或完整 ISO，两种都兼容
    if (RegExp(r'^\d{2}:\d{2}\$').hasMatch(v)) return v;
    if (v.length >= 16) {
      final t = v.substring(11, 16);
      if (RegExp(r'^\d{2}:\d{2}\$').hasMatch(t)) return t;
    }
    return null;
  }

  Widget _buildWeather(ThemeState theme) {
    final current = weatherCurrent(widget.weather);
    final today = weatherDay(widget.weather);
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
    final prompt = weatherCardPrompt(widget.weather);
    final sunrise = _shortTime(today['sunrise']?.toString());
    final sunset = _shortTime(today['sunset']?.toString());

    return Material(
      color: Colors.transparent,
      child: GlowWrap(
        accentColor: theme.accentColor,
        radius: 50,
        borderRadius: BorderRadius.circular(XqDecorations.radiusHero),
        onTap: widget.onOpenDetail,
        child: _shell(
          theme,
          flash: _showFlash,
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
                          widget.cityName.isEmpty ? '城市待确认' : widget.cityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.locationStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '详情',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                                    fontSize: 76,
                                    height: 0.98,
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: -3,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 11,
                                        color: theme.accentColor.withAlpha(160),
                                      ),
                                      Text(
                                        high == null ? '--' : '$high°',
                                        style: TextStyle(
                                          color: theme.textSecondary,
                                          fontSize: 12,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 11,
                                        color: theme.accentColor.withAlpha(110),
                                      ),
                                      Text(
                                        low == null ? '--' : '$low°',
                                        style: TextStyle(
                                          color: theme.textSecondary,
                                          fontSize: 12,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (feelsLike != null)
                              _metricPill(theme, '体感', '$feelsLike°'),
                            if (humidity != null)
                              _metricPill(theme, '湿度', '$humidity%'),
                            if (wind != null) _metricPill(theme, '风', '$wind'),
                            if (sunrise != null && sunset != null)
                              _metricPill(theme, '日出日落', '$sunrise/$sunset'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 94,
                    height: 94,
                    padding: const EdgeInsets.all(8),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.cardColor.withAlpha(
                        theme.isDark ? 150 : 180,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.borderColor.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedWeatherIllustration(
                                code: code,
                                inkColor: theme.ink,
                                accentColor: theme.gold,
                                size: const Size(72, 50),
                                isNight: _isNight(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              weatherIcon(code, weatherText),
                              color: theme.accentColor,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                weatherText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: theme.gold.withAlpha(theme.isDark ? 10 : 14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.gold.withAlpha(theme.isDark ? 24 : 22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 15,
                      color: theme.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '试试去心情页制作卡片吧',
                style: TextStyle(
                  color: theme.textTertiary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: theme.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    weatherUpdatedText(widget.updatedAt),
                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                  ),
                  if (widget.statusText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.refreshing
                            ? theme.accentColor.withAlpha(20)
                            : theme.textSecondary.withAlpha(18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.refreshing)
                            SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.4,
                                color: theme.accentColor,
                              ),
                            ),
                          if (widget.refreshing) const SizedBox(width: 4),
                          Text(
                            widget.statusText!,
                            style: TextStyle(
                              color: widget.refreshing
                                  ? theme.accentColor
                                  : theme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isNight() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour < 6 || hour >= 19;
  }

  Widget _metricPill(ThemeState theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.accentColor.withAlpha(35)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _shell(ThemeState theme, {required Widget child, bool flash = false}) {
    return Container(
      key: ValueKey('${widget.loading}_${widget.error}_${widget.cityName}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: XqDecorations.heroCard(
        theme.isDark ? theme.cardColor : theme.cardElevated,
        theme.isDark ? theme.cardElevated : theme.cardColor,
        theme.borderColor,
        dark: theme.isDark,
        glow: flash ? theme.successColor : theme.accentColor,
      ),
      child: child,
    );
  }
}
