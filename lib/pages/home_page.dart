import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../constants/mood.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../utils/solar_term_utils.dart';
import '../utils/time_utils.dart';
import '../utils/weather_utils.dart';
import '../utils/geo_utils.dart';
import '../widgets/weather_sky.dart';
import '../theme/xq_colors.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/mood_card_maker.dart';
import '../theme/xq_typography.dart';
import '../widgets/stagger_in.dart';
import '../widgets/xq/xq_kit.dart';
import 'weather_detail_page.dart';

/// 首页「天色」：上半屏是今天真实的天（天况 × 时辰），宋体大字压在天上；
/// 下半屏宣纸上是问候 → 今天（楷体摘句）→ 主操作「记一笔」→ 那年今日。
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _weatherLatKey = 'weather_lat';
  static const _weatherLonKey = 'weather_lon';
  static const _weatherCityKey = 'weather_city';
  static const _weatherUpdatedAtKey = 'weather_updated_at';
  static const _weatherDataKey = 'weather_data';
  static const _locCacheVerKey = 'loc_cache_ver';
  // v2：旧版 IP 定位兜底曾把服务器所在城市（杭州）的坐标写入缓存，
  // 升级后清一次位置缓存，强制按真实位置重新定位。
  static const _locCacheVer = 2;

  Map<String, dynamic>? _weather;
  String _currentCity = '';
  String _locationStatus = '正在定位';
  DateTime? _weatherUpdatedAt;
  final _citySearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _cityResults = [];
  bool _loading = true;
  Map<String, dynamic>? _memory; // 那年今日
  List<Map<String, dynamic>> _todayMoods = const [];
  int _seenMoodRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadCachedFirst();
    _loadMemory();
  }

  /// 今天的记录 + 那年今日（往年同月同日最近的一条），共用一次全量拉取
  Future<void> _loadMemory() async {
    try {
      final data = await Api.getAllMoods();
      final moods = (data['moods'] as List?) ?? const [];
      final now = DateTime.now();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final today = '${now.year}-$mm-$dd';
      final suffix = '-$mm-$dd';
      final todays = <Map<String, dynamic>>[];
      Map<String, dynamic>? best;
      var bestYear = 0;
      for (final m in moods) {
        if (m is! Map) continue;
        final date = m['date']?.toString() ?? '';
        if (date == today) {
          todays.add(Map<String, dynamic>.from(m));
          continue;
        }
        if (!date.endsWith(suffix)) continue;
        final year = int.tryParse(date.substring(0, 4)) ?? 0;
        if (year >= now.year) continue;
        if (year > bestYear) {
          bestYear = year;
          best = Map<String, dynamic>.from(m);
        }
      }
      todays.sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
      if (!mounted) return;
      setState(() {
        _memory = best;
        _todayMoods = todays;
      });
    } catch (_) {
      // 未登录/网络失败都静默
    }
  }

  Future<void> _loadCachedFirst() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_locCacheVerKey) != _locCacheVer) {
      for (final key in [
        _weatherLatKey,
        _weatherLonKey,
        _weatherCityKey,
        _weatherUpdatedAtKey,
        _weatherDataKey,
        'cityLat',
        'cityLon',
      ]) {
        await prefs.remove(key);
      }
      await prefs.setInt(_locCacheVerKey, _locCacheVer);
    }
    final lat = prefs.getDouble(_weatherLatKey);
    final lon = prefs.getDouble(_weatherLonKey);
    final city = prefs.getString(_weatherCityKey);
    final dataStr = prefs.getString(_weatherDataKey);
    final updatedAt = DateTime.tryParse(
      prefs.getString(_weatherUpdatedAtKey) ?? '',
    );

    if (lat != null && lon != null && city != null && dataStr != null) {
      try {
        final data = Map<String, dynamic>.from(json.decode(dataStr) as Map);
        if (mounted) {
          setState(() {
            _weather = data;
            _currentCity = city;
            _weatherUpdatedAt = updatedAt;
            _loading = false;
          });
        }
      } catch (_) {}
    }

    // 缓存新鲜（30分钟内）则不触发网络请求
    if (updatedAt != null &&
        DateTime.now().difference(updatedAt).inMinutes < 30) {
      return;
    }
    _loadWeather();
  }

  @override
  void dispose() {
    _citySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWeather({
    double? lat,
    double? lon,
    String? name,
    String? source,
  }) async {
    final hasCache = _weather != null;
    if (mounted) {
      setState(() {
        if (hasCache) {
          _loading = false;
        } else {
          _loading = true;
        }
        _locationStatus = source ?? '正在定位';
      });
    }

    if (lat != null && lon != null) {
      await _fetchWeatherFor(
        _WeatherLocation(
          lat: lat,
          lon: lon,
          city: name?.trim().isNotEmpty == true ? name!.trim() : '手动城市',
          status: source ?? '手动城市',
          cacheable: true,
        ),
      );
      return;
    }

    // 真实 GPS 定位优先：打开/刷新先拿当前所在城市，
    // 只有 GPS 失败（未开定位/未授权/无信号）才回退到上次位置，再退到 IP。
    final failures = <String>[];
    for (final resolver in [_systemLocation, _cachedLocation, _ipLocation]) {
      try {
        final location = await resolver();
        if (location == null) continue;
        await _fetchWeatherFor(location);
        return;
      } on ApiException catch (e) {
        if (e.statusCode == 401) return;
        failures.add(e.message);
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.trim().isNotEmpty) failures.add(msg);
      }
    }

    if (!mounted) return;
    setState(() {
      if (hasCache) {
        _loading = false;
      } else {
        _weather = null;
        _currentCity = '';
        _locationStatus = '定位失败';
        _weatherUpdatedAt = null;
      }
    });

    // Default fallback — Beijing
    if (!hasCache && _weather == null && mounted) {
      await _fetchWeatherFor(
        _WeatherLocation(
          lat: 39.9042,
          lon: 116.4074,
          city: '北京',
          status: '默认位置',
          cacheable: false,
        ),
      );
    }
  }

  Future<void> _fetchWeatherFor(_WeatherLocation location) async {
    final data = await Api.getWeather(location.lat, location.lon);
    final updatedAt = DateTime.now();
    if (location.cacheable) {
      await _cacheLocation(location, updatedAt, data);
    }
    if (!mounted) return;
    setState(() {
      _weather = Map<String, dynamic>.from(data);
      _currentCity = location.city;
      _locationStatus = location.status;
      _weatherUpdatedAt = updatedAt;
      _loading = false;
    });
  }

  Future<String> _resolveCity(
    double lat,
    double lon, {
    required String fallback,
  }) async {
    // 始终返回最近城市（不再有距离限制）
    final nearest = findNearestCity(lat, lon);
    if (nearest != null) return '${nearest.name}，${nearest.province}，中国';
    return fallback;
  }

  bool _isGenericCity(String city) {
    final text = city.trim();
    if (text.isEmpty) return true;
    const generics = {
      '当前位置',
      '上次位置',
      '定位城市',
      '手动城市',
      'GPS定位',
      'IP 定位',
      'IP 定位城市',
      '正在定位',
      '使用上次位置',
      '城市待确认',
    };
    if (generics.contains(text)) return true;
    if (!RegExp(r'[一-鿿]').hasMatch(text)) return true;
    return false;
  }

  Future<_WeatherLocation?> _systemLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('系统定位未开启');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!mounted) return null;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('允许定位天气'),
          content: const Text('用于显示你所在城市天气，不会用于好友或公开展示。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('暂不允许'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (!mounted || ok != true) throw Exception('未开启定位权限');
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) throw Exception('未开启定位权限');
    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限已被系统拒绝，请在设置中开启或手动选择城市');
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // 重试一次，降低精度要求
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
    }
    final city = await _resolveCity(
      position.latitude,
      position.longitude,
      fallback: '定位城市',
    );
    return _WeatherLocation(
      lat: position.latitude,
      lon: position.longitude,
      city: city,
      status: _isGenericCity(city) ? 'GPS定位 · 城市待确认' : 'GPS定位',
      cacheable: true,
    );
  }

  Future<_WeatherLocation?> _cachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_weatherLatKey);
    final lon = prefs.getDouble(_weatherLonKey);
    if (lat == null || lon == null) return null;
    // 始终从坐标反查城市名（不用缓存的字符串，避免换城市后名称不更新）
    final city = await _resolveCity(lat, lon, fallback: '上次位置');
    return _WeatherLocation(
      lat: lat,
      lon: lon,
      city: city,
      status: _isGenericCity(city) ? '使用上次位置 · 城市待确认' : '使用上次位置',
      cacheable: false,
    );
  }

  /// 直接从客户端调用 ip-api.com，获取手机真实 IP 对应的城市
  Future<Map<String, dynamic>> _clientIpLocation() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=status,lat,lon,city,regionName,country&lang=zh',
            ),
          )
          .timeout(const Duration(seconds: 5));
      final j = json.decode(res.body) as Map<String, dynamic>;
      if (j['status'] == 'success') return j;
    } catch (_) {}
    return {'status': 'fail'};
  }

  Future<_WeatherLocation?> _ipLocation() async {
    // ① 国内服务优先：城市级解析，对国内手机运营商 IP 明显更准
    //    （运营商网关常把 IP 归到省会的机房城市，这正是"定位到杭州"的残余来源）
    final cn = await _chinaIpLocation();
    if (cn != null) return cn;

    // ② ip-api 国际兜底（自带经纬度）
    final loc = await _clientIpLocation();
    if (loc['status'] != 'success' ||
        loc['lat'] == null ||
        loc['lon'] == null) {
      throw Exception('IP 定位失败');
    }
    final ipLat = (loc['lat'] as num).toDouble();
    final ipLng = (loc['lon'] as num).toDouble();
    final ipCity = loc['city']?.toString() ?? '';
    final ipRegion = loc['regionName']?.toString() ?? '';
    String city;
    if (ipCity.isNotEmpty && ipCity != '未知') {
      city = ipRegion.isNotEmpty && ipRegion != '未知'
          ? '$ipCity，$ipRegion，中国'
          : '$ipCity，中国';
    } else {
      final nearest = findNearestCity(ipLat, ipLng);
      city = nearest != null
          ? '${nearest.name}，${nearest.province}，中国'
          : 'IP 定位城市';
    }
    return _WeatherLocation(
      lat: ipLat,
      lon: ipLng,
      city: city,
      status: 'IP 定位',
      cacheable: true,
    );
  }

  /// pconline（太平洋电脑网）IP 服务：HTTPS 免 key、国内网络稳定、城市级。
  /// 返回 GBK 编码的 JSONP，需要按 GBK 解码；解析失败返回 null 走下一级。
  Future<_WeatherLocation?> _chinaIpLocation() async {
    try {
      final res = await http
          .get(Uri.parse('https://whois.pconline.com.cn/ipJson.jsp?json=true'))
          .timeout(const Duration(seconds: 4));
      final body = gbk.decode(res.bodyBytes);
      final i = body.indexOf('{');
      final j = body.lastIndexOf('}');
      if (i < 0 || j <= i) return null;
      final obj = json.decode(body.substring(i, j + 1));
      final city = (obj['city'] ?? '').toString().replaceAll('市', '');
      final pro = (obj['pro'] ?? '').toString().replaceAll('省', '');
      if (city.isEmpty) return null;
      final matches = searchCityLocally(city);
      if (matches.isEmpty) return null;
      final c = matches.first;
      return _WeatherLocation(
        lat: c.lat,
        lon: c.lng,
        city: '$city，$pro，中国',
        status: 'IP 定位',
        cacheable: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheLocation(
    _WeatherLocation location,
    DateTime updatedAt,
    Map<String, dynamic> weatherData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_weatherLatKey, location.lat);
    await prefs.setDouble(_weatherLonKey, location.lon);
    await prefs.setDouble('cityLat', location.lat);
    await prefs.setDouble('cityLon', location.lon);
    if (_isGenericCity(location.city)) {
      await prefs.remove(_weatherCityKey);
    } else {
      await prefs.setString(_weatherCityKey, location.city);
    }
    await prefs.setString(_weatherUpdatedAtKey, updatedAt.toIso8601String());
    await prefs.setString(_weatherDataKey, json.encode(weatherData));
  }

  void _onCitySearch(String q) async {
    if (q.trim().isEmpty) {
      if (mounted) setState(() => _cityResults = []);
      return;
    }
    final results = searchCityLocally(q);
    if (mounted) {
      setState(() {
        _cityResults = results
            .map(
              (c) => {
                'name': c.name,
                'admin1': c.province,
                'country': '中国',
                'latitude': c.lat,
                'longitude': c.lng,
              },
            )
            .toList();
      });
    }
  }

  void _pickCity(Map<String, dynamic> c) {
    final label = [
      c['name'],
      c['admin1'],
      c['country'],
    ].whereType<String>().where((s) => s.isNotEmpty).join('，');
    _citySearchCtrl.clear();
    _cityResults = [];
    if (Navigator.canPop(context)) Navigator.pop(context);
    _loadWeather(
      lat: (c['latitude'] as num).toDouble(),
      lon: (c['longitude'] as num).toDouble(),
      name: label,
      source: '手动城市',
    );
  }

  Future<void> _openWeatherDetail() async {
    if (_weather == null) return;
    final action = await Navigator.push<WeatherDetailAction>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => WeatherDetailPage(
          weather: _weather!,
          cityName: _currentCity,
          locationStatus: _locationStatus,
          updatedAt: _weatherUpdatedAt,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (action == WeatherDetailAction.relocate) {
      _loadWeather();
    } else if (action == WeatherDetailAction.chooseCity) {
      _openCitySheet();
    }
  }

  void _openMood() {
    MainScaffold.switchToTab(context, 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final appState = context.watch<AppState>();
    if (appState.moodRevision != _seenMoodRevision) {
      _seenMoodRevision = appState.moodRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMemory());
    }
    final now = DateTime.now();
    final media = MediaQuery.of(context);

    final current = _weather != null
        ? _weather!['current'] as Map<String, dynamic>?
        : null;
    final today = _weather != null
        ? weatherDay(_weather, key: 'today')
        : const <String, dynamic>{};
    final cond = current?['weather']?.toString();
    final temp = weatherInt(current?['temp_current']);
    final condition = skyConditionFor(weatherInt(current?['weather_code']), cond);
    final time = skyTimeFor(
      now,
      sunrise: today['sunrise']?.toString(),
      sunset: today['sunset']?.toString(),
    );
    final palette = SkyPalette.of(condition, time);
    final dayOfYear = now.difference(DateTime(now.year)).inDays;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: RefreshIndicator(
        edgeOffset: media.padding.top,
        onRefresh: () async {
          await Future.wait([_loadWeather(), _loadMemory()]);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 天色占首屏约 56%，矮屏至少 380
            final skyH = (constraints.maxHeight * 0.56).clamp(380.0, 560.0).toDouble();
            return ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AnnotatedRegion<SystemUiOverlayStyle>(
                  value: palette.darkText
                      ? SystemUiOverlayStyle.dark
                      : SystemUiOverlayStyle.light,
                  child: _buildSky(
                    theme: theme,
                    palette: palette,
                    condition: condition,
                    time: time,
                    height: skyH,
                    topInset: media.padding.top,
                    cond: cond,
                    temp: temp,
                    now: now,
                    dayOfYear: dayOfYear,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggerIn(
                        index: 0,
                        child: Text(
                          _greeting(now, appState),
                          style: XqTypography.headlineLarge.copyWith(
                            color: theme.textPrimary,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      StaggerIn(index: 1, child: _buildToday(theme, cond)),
                      const SizedBox(height: 28),
                      StaggerIn(
                        index: 2,
                        child: SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _openMood,
                            child: Text(
                              _todayMoods.isEmpty ? '记一笔' : '再记一笔',
                              style: const TextStyle(letterSpacing: 6, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      if (_memory != null) ...[
                        const SizedBox(height: 40),
                        StaggerIn(index: 3, child: _buildMemoryLine(theme)),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _greeting(DateTime now, AppState appState) {
    final h = now.hour;
    final greet = h < 5
        ? '夜深了'
        : h < 11
        ? '早上好'
        : h < 14
        ? '中午好'
        : h < 18
        ? '下午好'
        : '晚上好';
    final name = appState.displayName.isNotEmpty ? appState.displayName : '朋友';
    return '$greet，$name。';
  }

  /// 天色：今天真实的天（天况 × 时辰），宋体大字压在天上。点天色看详情。
  Widget _buildSky({
    required ThemeState theme,
    required SkyPalette palette,
    required SkyCondition condition,
    required SkyTime time,
    required double height,
    required double topInset,
    required String? cond,
    required int? temp,
    required DateTime now,
    required int dayOfYear,
  }) {
    const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    final dateLine =
        '${chineseNumber(now.month)}月${chineseNumber(now.day)}日 · ${weekdays[now.weekday % 7]}';
    final city = _currentCity.isEmpty ? '城市待确认' : _currentCity.split('，').first;
    final ready = cond != null && temp != null;
    final compact = height < 430;
    final seal = palette.darkText ? XqColors.sujianSeal : XqColors.sujianDarkSeal;

    return Semantics(
      button: ready,
      label: ready ? '$city，$cond，$temp 度，查看天气详情' : null,
      child: GestureDetector(
        onTap: ready ? _openWeatherDetail : null,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: WeatherSkyPainter(
                    palette: palette,
                    condition: condition,
                    paper: theme.backgroundColor,
                    seed: now.month * 31 + now.day,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(28, topInset + 18, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dateLine,
                              style: TextStyle(
                                color: palette.onSkySoft,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        XqSeal(
                          char: currentSolarTerm(now),
                          color: seal,
                          size: 36,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : height * 0.09),
                    Semantics(
                      button: true,
                      label: '换城市',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openCitySheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '$city ›',
                            style: TextStyle(
                              color: palette.onSkySoft,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!ready)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: _loading ? null : _loadWeather,
                          child: Text(
                            _loading ? '正在看天…' : '天气没取到，点这里重试',
                            style: XqTypography.headlineLarge.copyWith(
                              color: palette.onSky,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      StaggerIn(
                        index: 0,
                        child: Text(
                          chineseTemperature(temp),
                          style: XqTypography.displayLarge.copyWith(
                            color: palette.onSky,
                            fontSize: compact ? 46 : 56,
                            height: 1.15,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggerIn(
                        index: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            '$cond。${skyLine(condition, time, dayOfYear: dayOfYear)}',
                            style: XqTypography.headlineSmall.copyWith(
                              color: palette.onSkySoft,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 今天：已记 → 最新一条（心情釉色点 + 时间 + 楷体「摘句」）；未记 → 一句留白
  Widget _buildToday(ThemeState theme, String? cond) {
    if (_todayMoods.isEmpty) {
      return Text(
        cond != null ? '$cond的一天，还没有写下什么。' : '今天还没有写下什么。',
        style: XqTypography.handwrittenBody.copyWith(
          color: theme.textSecondary,
          height: 1.7,
        ),
      );
    }
    final latest = _todayMoods.first;
    final score = (latest['emotion_type'] as num?)?.toInt() ?? 0;
    final notes = (latest['notes']?.toString() ?? '').trim();
    final hm = TimeUtils.hm(latest['created_at']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(moodColors[score] ?? 0xFF7C918C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '今天 · ${moodLabels[score] ?? ''}',
              style: TextStyle(color: theme.textSecondary, fontSize: 13, letterSpacing: 1),
            ),
            if (hm.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                hm,
                style: TextStyle(
                  color: theme.gold,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const Spacer(),
            if (_todayMoods.length > 1)
              Text(
                '共 ${_todayMoods.length} 笔',
                style: TextStyle(color: theme.textTertiary, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          notes.isEmpty ? '只留下了一个心情。' : '「$notes」',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: XqTypography.handwrittenBody.copyWith(
            color: theme.textPrimary,
            fontSize: 18,
            height: 1.75,
          ),
        ),
      ],
    );
  }

  /// 那年今日：一条细线下的一行旧字（点击仍可制卡）
  Widget _buildMemoryLine(ThemeState theme) {
    final m = _memory!;
    final date = m['date']?.toString() ?? '';
    final year = int.tryParse(date.substring(0, 4));
    final yearsAgo = year == null ? '' : '${DateTime.now().year - year} 年前';
    final score = (m['emotion_type'] as num?)?.toInt() ?? 0;
    final code = int.tryParse(m['weather_code']?.toString() ?? '');
    final weatherText = weatherTextForCode(code);
    final notes = (m['notes']?.toString() ?? '').trim();
    final meta = [
      if (yearsAgo.isNotEmpty) yearsAgo,
      if (weatherText.isNotEmpty) weatherText,
      moodLabels[score] ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Semantics(
      button: true,
      label: '那年今日，制成卡片',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          MoodCardMaker.show(
            context,
            date: date,
            moodLabel: moodLabels[score] ?? '',
            moodScore: score,
            text: notes,
            tags: const [],
            weatherText: weatherText,
            cityName: '那年今日',
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 18),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.borderColor, width: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '那年今日',
                    style: XqTypography.headlineSmall.copyWith(color: theme.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(meta, style: TextStyle(color: theme.textTertiary, fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notes.isEmpty ? '那天只留下了一个心情。' : notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: XqTypography.content,
                  fontFamilyFallback: XqTypography.contentFallback,
                  color: theme.textSecondary,
                  fontSize: 15.5,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 换城市：原内联搜索面板改为底部抽屉
  Future<void> _openCitySheet() async {
    final theme = context.read<ThemeState>();
    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: _buildCitySearch(theme),
        ),
      ),
    );
  }

  Widget _buildCitySearch(ThemeState theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _citySearchCtrl,
                autofocus: true,
                onChanged: _onCitySearch,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: '搜索城市...',
                  hintStyle: TextStyle(
                    color: theme.textSecondary.withAlpha(150),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: theme.accentColor,
                      width: 1.2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: theme.accentColor,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: theme.textSecondary),
            ),
          ],
        ),
        if (_citySearchCtrl.text.isNotEmpty && _cityResults.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '暂无结果，换个城市名试试',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
          ),
        ..._cityResults.map(
          (c) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              c['name'] ?? '',
              style: TextStyle(color: theme.textPrimary),
            ),
            subtitle: Text(
              '${c['admin1'] ?? ''} ${c['country'] ?? ''}',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
            trailing: Text(
              '切换',
              style: TextStyle(color: theme.accentColor, fontSize: 13),
            ),
            onTap: () => _pickCity(c),
          ),
        ),
      ],
    );
  }
}

/// 心情定位数据（首页内部使用）
class _WeatherLocation {
  final double lat;
  final double lon;
  final String city;
  final String status;
  final bool cacheable;
  const _WeatherLocation({
    required this.lat,
    required this.lon,
    required this.city,
    required this.status,
    required this.cacheable,
  });
}
