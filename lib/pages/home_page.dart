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
import '../widgets/xq/xq_icons.dart';
import '../widgets/xq/xq_surface.dart';
import '../widgets/xq/xq_paper.dart';
import '../theme/xq_paper_textures.dart';
import '../data/poems.dart';
import 'story_page.dart';
import 'capsule_page.dart';
import 'card_album_page.dart';
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
  final _scrollCtrl = ScrollController();

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
    _scrollCtrl.dispose();
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 面板起点：天色占首屏约 58%
          final sheetTop = (constraints.maxHeight * 0.58).clamp(400.0, 540.0).toDouble();
          return Stack(
            children: [
              // 背后：会动的天，固定不随内容走（只做视差）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: sheetTop + 90,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: palette.darkText
                      ? SystemUiOverlayStyle.dark
                      : SystemUiOverlayStyle.light,
                  child: WeatherSkyScene(
                    palette: palette,
                    condition: condition,
                    paper: theme.backgroundColor,
                    seed: now.month * 31 + now.day,
                    orbAt: const Offset(0.655, 0.1),
                    scroll: _scrollCtrl,
                    motif: skyMotifFor(condition),
                  ),
                ),
              ),
              // 前面：天上的字 + 自下而上覆盖天色的纸面面板
              RefreshIndicator(
                edgeOffset: media.padding.top,
                onRefresh: () async {
                  await Future.wait([_loadWeather(), _loadMemory()]);
                },
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: AnimatedBuilder(
                        animation: _scrollCtrl,
                        builder: (context, child) {
                          final y = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
                          return Opacity(
                            opacity: (1 - y / (sheetTop * 0.45)).clamp(0.0, 1.0),
                            child: child,
                          );
                        },
                        child: _buildHero(
                          theme: theme,
                          palette: palette,
                          condition: condition,
                          time: time,
                          height: sheetTop,
                          topInset: media.padding.top,
                          cond: cond,
                          temp: temp,
                          now: now,
                          dayOfYear: dayOfYear,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildSheet(theme, appState, now, cond)),
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: XqPaperPage(child: SizedBox.expand()),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
    return '$greet，$name';
  }

  /// 天上的字：城市、展示体大字温度、一句短句与日期节气；右上角题跋（公版古诗竖排两列 + 落款作者 + 节气白文印）
  Widget _buildHero({
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
    final city = _currentCity.isEmpty ? '城市待确认' : _currentCity.split('，').first;
    final ready = cond != null && temp != null;
    final seal = palette.darkText ? XqColors.sujianSeal : XqColors.sujianDarkSeal;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final term = currentSolarTerm(now);
    final poem = poemFor(condition, time, now);
    final dateLine =
        '${chineseNumber(now.month)}月${chineseNumber(now.day)}日 ${weekdays[now.weekday % 7]} · $term第${chineseNumber(daysIntoSolarTerm(now))}天';

    Widget vertical(String text, {double size = 17, Color? color}) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ch in text.characters)
              Text(
                ch,
                style: XqTypography.headlineSmall.copyWith(
                  color: color ?? palette.onSkySoft,
                  fontSize: size,
                  height: 1.16,
                ),
              ),
          ],
        );

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // 题跋：右起第一列是首句；落款低一字起，下压节气印
          Positioned(
            top: topInset + 22,
            right: 18,
            child: Semantics(
              label: '${poem.lines.join('，')}。${poem.author}《${poem.title}》。今日$term',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      children: [
                        vertical(poem.author, size: 12.5),
                        const SizedBox(height: 8),
                        XqSeal(char: term, color: seal, size: 28, style: XqSealStyle.bai, angle: 0.03),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  vertical(poem.lines[1], color: palette.onSky.withAlpha(215)),
                  const SizedBox(width: 6),
                  vertical(poem.lines[0], color: palette.onSky.withAlpha(215)),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 10, 104, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: '换城市，当前$city',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _openCitySheet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          XqIcon(XqIcons.locate, size: 15, color: palette.onSkySoft),
                          const SizedBox(width: 6),
                          Text(city, style: TextStyle(color: palette.onSky, fontSize: 15)),
                          Icon(Icons.expand_more_rounded, size: 18, color: palette.onSkySoft),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  button: ready,
                  label: ready ? '$cond，$temp 度，查看天气详情' : null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: ready ? _openWeatherDetail : (_loading ? null : _loadWeather),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ready
                          ? TweenAnimationBuilder<double>(
                              tween: Tween(begin: reduce ? 1 : 0, end: 1),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutQuart,
                              builder: (context, v, child) => Opacity(
                                opacity: v,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - v) * 14),
                                  child: child,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chineseTemperature(temp),
                                    style: XqTypography.displayLarge.copyWith(
                                      color: palette.onSky,
                                      fontSize: height < 450 ? 60 : 72,
                                      height: 1.05,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '$cond。${skyLine(condition, time, dayOfYear: dayOfYear)}',
                                    style: XqTypography.headlineSmall.copyWith(
                                      color: palette.onSkySoft,
                                      fontSize: 17,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dateLine,
                                    style: TextStyle(color: palette.onSkySoft, fontSize: 12.5, height: 1.5),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              _loading ? '正在看天…' : '天气没取到，点这里重试',
                              style: XqTypography.headlineLarge.copyWith(color: palette.onSky),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 叠上来的一张纸（L2）：毛边顶、纸纹、向上一道影，盖住山脚；上面放一张「今日笺」（L1）
  Widget _buildSheet(ThemeState theme, AppState appState, DateTime now, String? cond) {
    return XqDeckleSheet(
      seed: now.day,
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggerIn(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                _greeting(now, appState),
                style: XqTypography.headlineLarge.copyWith(
                  color: theme.textPrimary,
                  fontSize: 23,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          StaggerIn(index: 1, child: _buildToday(theme, cond)),
          const SizedBox(height: 14),
          StaggerIn(
            index: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _openMood,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    XqIcon(XqIcons.write, size: 18, color: theme.textOnAccent),
                    const SizedBox(width: 10),
                    Text(
                      _todayMoods.isEmpty ? '记一笔' : '再记一笔',
                      style: const TextStyle(fontSize: 16, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          StaggerIn(index: 3, child: _buildShortcuts(theme)),
          if (_memory != null) ...[
            const SizedBox(height: 30),
            StaggerIn(index: 4, child: _buildMemoryCard(theme)),
          ],
        ],
      ),
    );
  }

  /// 朱丝栏：信笺上的淡朱界行
  Widget _ruled(ThemeState theme, Widget child, {double spacing = 32}) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: LinedPaperPainter(
                lineColor: theme.sealColor.withAlpha(theme.isDark ? 70 : 52),
                lineSpacing: spacing,
                showMarginLine: false,
              ),
            ),
          ),
          child,
        ],
      );

  /// 今日笺（L1）：已记 → 颜料点 · 心情 · 时间，楷体摘句写在朱丝栏上，右下钤一枚「记」；未记 → 一张空笺。
  Widget _buildToday(ThemeState theme, String? cond) {
    if (_todayMoods.isEmpty) {
      return XqSurface(
        onTap: _openMood,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今日笺', style: TextStyle(color: theme.textTertiary, fontSize: 12.5)),
            const SizedBox(height: 4),
            _ruled(
              theme,
              Text(
                cond != null ? '$cond的一天，还空着。\n写下第一笔。' : '今天还空着。\n写下第一笔。',
                style: XqTypography.handwrittenBody.copyWith(
                  color: theme.textSecondary,
                  fontSize: 18,
                  height: 32 / 18,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final latest = _todayMoods.first;
    final score = (latest['emotion_type'] as num?)?.toInt() ?? 0;
    final notes = (latest['notes']?.toString() ?? '').trim();
    final hm = TimeUtils.hm(latest['created_at']);
    final moodColor = Color(moodColors[score] ?? 0xFF7A7871);
    return XqSurface(
      onTap: _openMood,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    XqPigmentDab(color: moodColor, size: 16, seed: score),
                    const SizedBox(width: 7),
                    Text(
                      moodLabels[score] ?? '',
                      style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                    if (hm.isNotEmpty)
                      Text(
                        hm,
                        style: TextStyle(
                          color: theme.textTertiary,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    const Spacer(),
                    if (_todayMoods.length > 1)
                      Text(
                        '今日 ${_todayMoods.length} 笔',
                        style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _ruled(
                  theme,
                  Padding(
                    padding: const EdgeInsets.only(right: 30),
                    child: Text(
                      notes.isEmpty ? '只留下了一个心情。' : '「$notes」',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: XqTypography.handwrittenBody.copyWith(
                        color: theme.textPrimary,
                        fontSize: 18,
                        height: 32 / 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: XqSeal(char: '记', color: theme.sealColor, size: 30, style: XqSealStyle.bai, angle: 0.09),
          ),
        ],
      ),
    );
  }

  /// 目录：一行三栏，上下乌丝栏、栏间界线（不是三张一样的卡片）
  Widget _buildShortcuts(ThemeState theme) {
    Widget entry(String title, String sub, Widget page) => Expanded(
          child: Semantics(
            button: true,
            label: '$title，$sub',
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(context, MaterialPageRoute(builder: (_) => page));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(title, style: XqTypography.headlineSmall.copyWith(color: theme.textPrimary, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(sub, style: TextStyle(color: theme.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
    Widget rule() => Container(width: 0.6, height: 34, color: theme.frameColor);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: theme.frameColor, width: 0.6)),
      ),
      child: Row(
        children: [
          entry('素笺', '写一篇长的', const StoryListPage()),
          rule(),
          entry('胶囊', '写给以后', const CapsulePage()),
          rule(),
          entry('卡片册', '做过的卡片', const CardAlbumPage()),
        ],
      ),
    );
  }

  /// 那年今日：一张泛黄的旧笺，点击制成卡片
  Widget _buildMemoryCard(ThemeState theme) {
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
    final aged = Color.lerp(
      theme.cardColor,
      theme.isDark ? const Color(0xFF3A3526) : const Color(0xFFE9D8B2),
      theme.isDark ? 0.35 : 0.42,
    )!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        XqSectionTitle('那年今日', caption: meta),
        XqSurface(
          color: aged,
          onTap: () {
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  notes.isEmpty ? '那天只留下了一个心情。' : notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: XqTypography.content,
                    fontFamilyFallback: XqTypography.contentFallback,
                    color: theme.textSecondary,
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('制成卡片', style: TextStyle(color: theme.accentColor, fontSize: 13)),
              Icon(Icons.chevron_right_rounded, size: 18, color: theme.accentColor),
            ],
          ),
        ),
      ],
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
