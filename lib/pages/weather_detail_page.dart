import 'package:flutter/material.dart';
import '../widgets/xq/xq_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../utils/weather_utils.dart';
import '../widgets/stagger_in.dart';
import '../widgets/weather_feedback_bar.dart';
import '../widgets/weather_sky.dart';
import '../widgets/xq/xq_surface.dart';
import '../widgets/xq/xq_paper.dart';

enum WeatherDetailAction { relocate, chooseCity }

/// 天气详情：上接首页同一幅天色，下面在宣纸上列「接下来」与「此刻」。
class WeatherDetailPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final media = MediaQuery.of(context);
    final now = DateTime.now();

    final current = weatherCurrent(weather);
    final today = weatherDay(weather);
    final tomorrow = weatherDay(weather, key: 'tomorrow', index: 1);
    final dayAfter = weatherDay(weather, key: 'day_after', index: 2);
    final weatherText = (current['weather'] ?? today['weather'] ?? '未知天气')
        .toString();
    final code =
        weatherInt(current['weather_code']) ??
        weatherInt(today['weather_code']);
    final currentTemp =
        weatherInt(current['temp_current']) ??
        weatherInt(today['temp_current']);
    final high = weatherInt(today['temp_max']);
    final low = weatherInt(today['temp_min']);
    final humidity =
        weatherInt(current['humidity']) ?? weatherInt(today['humidity']);
    final feelsLike = weatherInt(current['feels_like']);
    final wind =
        weatherInt(current['wind_current']) ?? weatherInt(today['wind']);
    // 服务端字段为 precip_prob（旧代码读 rain_prob，降水从未显示）
    final rain =
        weatherInt(today['precip_prob']) ?? weatherInt(today['rain_prob']);
    final sunrise = today['sunrise']?.toString();
    final sunset = today['sunset']?.toString();

    final condition = skyConditionFor(code, weatherText);
    final time = skyTimeFor(now, sunrise: sunrise, sunset: sunset);
    final palette = SkyPalette.of(condition, time);
    final city = cityName.isEmpty ? '当前位置' : cityName.split('，').first;
    final skyH = (media.size.height * 0.4).clamp(300.0, 400.0).toDouble();

    final days = [
      ('今天', today),
      if (tomorrow.isNotEmpty) ('明天', tomorrow),
      if (dayAfter.isNotEmpty) ('后天', dayAfter),
    ];

    final facts = <(String, String, String?)>[
      if (feelsLike != null)
        (
          '体感',
          '$feelsLike°',
          currentTemp == null || (feelsLike - currentTemp).abs() < 2
              ? '和实际温度差不多'
              : feelsLike < currentTemp
              ? '比实际低 ${currentTemp - feelsLike}°，多穿一件'
              : '比实际高 ${feelsLike - currentTemp}°，有点闷',
        ),
      if (humidity != null)
        (
          '湿度',
          '$humidity%',
          humidity > 70
              ? '偏潮，体感会闷一些'
              : humidity < 30
              ? '偏干，记得喝水'
              : '干湿正好',
        ),
      if (wind != null)
        (
          '风',
          '$wind km/h',
          wind > 30
              ? '风大，出门当心'
              : wind > 15
              ? '有风，会比实际凉一些'
              : '微风',
        ),
      if (rain != null)
        (
          '降水',
          '$rain%',
          rain >= 60
              ? '多半会下，带伞'
              : rain >= 30
              ? '可能会下，备一把伞'
              : '不太会下',
        ),
      if (sunrise != null && sunset != null)
        ('日出 · 日落', '$sunrise · $sunset', null),
    ];

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyH + 80,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: palette.darkText
                  ? SystemUiOverlayStyle.dark
                  : SystemUiOverlayStyle.light,
              child: WeatherSkyScene(
                palette: palette,
                condition: condition,
                paper: theme.backgroundColor,
                seed: now.month * 31 + now.day,
                orbAt: const Offset(0.78, 0.2),
                motif: skyMotifFor(condition),
                motifAt: const Offset(0.3, 0.8),
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: [
              SizedBox(
                height: skyH,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    media.padding.top + 4,
                    24,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.pop(context),
                        icon: XqIcon(XqIcons.back,
                          color: palette.onSky,
                          size: 22,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$city · ${weatherUpdatedText(updatedAt)}',
                              style: TextStyle(
                                color: palette.onSkySoft,
                                fontSize: 13,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentTemp == null
                                  ? weatherText
                                  : chineseTemperature(currentTemp),
                              style: XqTypography.displayLarge.copyWith(
                                color: palette.onSky,
                                fontSize: 52,
                                height: 1.12,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                weatherText,
                                if (high != null && low != null)
                                  '最低 $low° · 最高 $high°',
                              ].join('　'),
                              style: XqTypography.headlineSmall.copyWith(
                                color: palette.onSkySoft,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: media.size.height - skyH,
                ),
                child: XqDeckleSheet(
                  seed: now.day + 7,
                  padding: const EdgeInsets.fromLTRB(18, 30, 18, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StaggerIn(
                        index: 0,
                        child: _section(theme, '接下来', [
                          for (final (label, d) in days)
                            _dayRow(theme, label, d),
                        ]),
                      ),
                      const SizedBox(height: 28),
                      if (facts.isNotEmpty)
                        StaggerIn(
                          index: 1,
                          child: _section(theme, '此刻', [
                            for (final f in facts)
                              _factRow(theme, f.$1, f.$2, f.$3),
                          ]),
                        ),
                      const SizedBox(height: 28),
                      StaggerIn(
                        index: 2,
                        child: WeatherFeedbackBar(
                          weatherText: weatherText,
                          currentTemp: currentTemp,
                          high: high,
                          low: low,
                          cityName: cityName,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                WeatherDetailAction.relocate,
                              ),
                              child: const Text('重新定位'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                WeatherDetailAction.chooseCity,
                              ),
                              child: const Text('换个城市'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          locationStatus,
                          style: TextStyle(
                            color: theme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 标题在外、行装在一张卡里
  Widget _section(ThemeState theme, String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        XqSectionTitle(title),
        XqSurface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1)
                  Container(height: 0.6, color: theme.borderColor),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 一天：日名（宋）· 天气 · 降水 · 最低/最高
  Widget _dayRow(ThemeState theme, String label, Map<String, dynamic> d) {
    final hi = weatherInt(d['temp_max']);
    final lo = weatherInt(d['temp_min']);
    final rain = weatherInt(d['precip_prob']) ?? weatherInt(d['rain_prob']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: XqTypography.headlineSmall.copyWith(
                color: theme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              d['weather']?.toString() ?? '',
              style: TextStyle(color: theme.textSecondary, fontSize: 15),
            ),
          ),
          if (rain != null && rain >= 20)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '降水 $rain%',
                style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
              ),
            ),
          Text(
            lo != null && hi != null ? '$lo° / $hi°' : '--',
            style: TextStyle(
              color: theme.gold,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// 一项：名 · 值（赭）· 一句白话
  Widget _factRow(ThemeState theme, String name, String value, String? note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              name,
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              note ?? '',
              style: TextStyle(color: theme.textTertiary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
