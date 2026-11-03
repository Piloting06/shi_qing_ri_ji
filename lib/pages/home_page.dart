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
  Map<String, int> _weekScores = const {}; // 本周（周一起）每天最后一笔的心情
  int _seenMoodRevision = 0;
  final _scrollCtrl = ScrollController();
  bool? _reveal; // 今天第一次打开：笺头画按版序套印显影；null = 还没判断

  @override
  void initState() {
    super.initState();
    _decideReveal();
    _loadCachedFirst();
    _loadMemory();
  }

  Future<void> _decideReveal() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final first = prefs.getString('sky_reveal_day') != today;
    if (first) await prefs.setString('sky_reveal_day', today);
    if (mounted) setState(() => _reveal = first);
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
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      String key(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final weekKeys = {
        for (var i = 0; i < 7; i++) key(monday.add(Duration(days: i))),
      };
      final week = <String, (String, int)>{}; // date → (created_at, score)
      Map<String, dynamic>? best;
      var bestYear = 0;
      for (final m in moods) {
        if (m is! Map) continue;
        final date = m['date']?.toString() ?? '';
        final score = (m['emotion_type'] as num?)?.toInt() ?? 0;
        if (weekKeys.contains(date) && score > 0) {
          final at = m['created_at']?.toString() ?? '';
          final prev = week[date];
          if (prev == null || at.compareTo(prev.$1) > 0) {
            week[date] = (at, score);
          }
        }
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
      todays.sort(
        (a, b) => (b['created_at']?.toString() ?? '').compareTo(
          a['created_at']?.toString() ?? '',
        ),
      );
      if (!mounted) return;
      setState(() {
        _memory = best;
        _todayMoods = todays;
        _weekScores = {for (final e in week.entries) e.key: e.value.$2};
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
          title: const Text('用定位看天气'),
          content: const Text('只用来显示你所在城市的天气，不给好友看，也不公开。'),
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
      throw Exception('定位被系统关了。可以去设置里打开，或者手动选城市。');
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
    final condition = skyConditionFor(
      weatherInt(current?['weather_code']),
      cond,
    );
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
          final sheetTop = (constraints.maxHeight * 0.58)
              .clamp(400.0, 540.0)
              .toDouble();
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
                  child: _reveal == null
                      ? ColoredBox(color: palette.top)
                      : WeatherSkyScene(
                          reveal: _reveal!,
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
              XqRefresh(
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
                          final y = _scrollCtrl.hasClients
                              ? _scrollCtrl.offset
                              : 0.0;
                          return Opacity(
                            opacity: (1 - y / (sheetTop * 0.45)).clamp(
                              0.0,
                              1.0,
                            ),
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
                          reveal: _reveal ?? false,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSheet(theme, appState, now, cond),
                    ),
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
    bool reveal = false,
  }) {
    const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    final city = _currentCity.isEmpty ? '城市待确认' : _currentCity.split('，').first;
    final ready = cond != null && temp != null;
    final seal = palette.darkText
        ? XqColors.sujianSeal
        : XqColors.sujianDarkSeal;
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
            child: _printIn(
              reveal && !reduce,
              const Interval(0.5, 0.8),
              child: Semantics(
                label:
                    '${poem.lines.join('，')}。${poem.author}《${poem.title}》。今日$term',
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
                          _printIn(
                            reveal && !reduce,
                            const Interval(0.8, 1),
                            stamp: true,
                            child: XqSeal(
                              char: term,
                              color: seal,
                              size: 28,
                              style: XqSealStyle.bai,
                              angle: 0.03,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    vertical(
                      poem.lines[1],
                      color: palette.onSky.withAlpha(215),
                    ),
                    const SizedBox(width: 6),
                    vertical(
                      poem.lines[0],
                      color: palette.onSky.withAlpha(215),
                    ),
                  ],
                ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          XqIcon(
                            XqIcons.locate,
                            size: 15,
                            color: palette.onSkySoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            city,
                            style: TextStyle(
                              color: palette.onSky,
                              fontSize: 15,
                            ),
                          ),
                          XqIcon(
                            XqIcons.chevronDown,
                            size: 18,
                            color: palette.onSkySoft,
                          ),
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
                    onTap: ready
                        ? _openWeatherDetail
                        : (_loading ? null : _loadWeather),
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
                                    style: TextStyle(
                                      color: palette.onSkySoft,
                                      fontSize: 12.5,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              _loading ? '正在看天…' : '天气没取到，点这里重试',
                              style: XqTypography.headlineLarge.copyWith(
                                color: palette.onSky,
                              ),
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

  /// 套印显影里的一版：按 [iv] 区间淡入；[stamp] 时像印落下（1.5 → 1）
  Widget _printIn(
    bool on,
    Interval iv, {
    required Widget child,
    bool stamp = false,
  }) {
    if (!on) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, v, child) {
        final t = Curves.easeOutQuart.transform(iv.transform(v));
        return Opacity(
          opacity: t,
          child: stamp
              ? Transform.scale(scale: 1.5 - 0.5 * t, child: child)
              : child,
        );
      },
      child: child,
    );
  }

  /// 叠上来的一张纸（L2）：招呼 → 今日笺（地脚是墨色「记一笔」）→ 本周 → 那年今日 → 目录
  Widget _buildSheet(
    ThemeState theme,
    AppState appState,
    DateTime now,
    String? cond,
  ) {
    final n = _todayMoods.length;
    final sub = n == 0 ? '今天还没写。' : '今天写了${chineseCount(n)}笔。';
    return XqDeckleSheet(
      seed: now.day,
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggerIn(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(now, appState),
                    style: XqTypography.headlineLarge.copyWith(
                      color: theme.textPrimary,
                      fontSize: 23,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: TextStyle(color: theme.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          StaggerIn(index: 1, child: _buildToday(theme, cond)),
          const SizedBox(height: 30),
          StaggerIn(index: 2, child: _buildWeek(theme, now)),
          if (_memory != null) ...[
            const SizedBox(height: 30),
            StaggerIn(index: 3, child: _buildMemoryCard(theme)),
          ],
          const SizedBox(height: 30),
          StaggerIn(index: 4, child: _buildShortcuts(theme)),
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

  /// 今日笺（L1）：今天写下的每一笔（时间 · 颜料 · 心情 · 楷体摘句，写在朱丝栏上），
  /// 记过的右下钤「记」；笺的地脚是墨色一栏「记一笔」，按钮和笺是一张纸。
  Widget _buildToday(ThemeState theme, String? cond) {
    final entries = _todayMoods.take(3).toList();
    final body = entries.isEmpty
        ? _ruled(
            theme,
            Text(
              cond != null ? '$cond。\n这一页还空着。' : '这一页还空着。',
              style: XqTypography.handwrittenBody.copyWith(
                color: theme.textTertiary,
                fontSize: 18,
                height: 32 / 18,
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _todayEntry(theme, entries[i], lead: i == 0),
              ],
              if (_todayMoods.length > entries.length)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '还有${chineseCount(_todayMoods.length - entries.length)}笔，在心情页',
                    style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
                  ),
                ),
            ],
          );

    return XqSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: '今日笺，去心情页',
            child: InkWell(
              onTap: _openMood,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日笺',
                          style: XqTypography.headlineSmall.copyWith(
                            color: theme.textSecondary,
                            fontSize: 15,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        body,
                      ],
                    ),
                  ),
                  if (entries.isNotEmpty)
                    Positioned(
                      right: 16,
                      top: 14,
                      child: XqSeal(
                        char: '记',
                        color: theme.sealColor,
                        size: 30,
                        style: XqSealStyle.bai,
                        angle: 0.09,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 地脚：墨色一栏
          Semantics(
            button: true,
            label: entries.isEmpty ? '记一笔' : '再记一笔',
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _openMood();
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  image: XqPaper.grain(theme.textOnAccent, strength: 0.35),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      XqIcon(
                        XqIcons.write,
                        size: 18,
                        color: theme.textOnAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        entries.isEmpty ? '记一笔' : '再记一笔',
                        style: TextStyle(
                          color: theme.textOnAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      XqIcon(
                        XqIcons.chevronRight,
                        size: 16,
                        color: theme.textOnAccent.withAlpha(170),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 今日笺里的一笔：第一笔写全（朱丝栏楷体，三行内），其余一行
  Widget _todayEntry(
    ThemeState theme,
    Map<String, dynamic> m, {
    required bool lead,
  }) {
    final score = (m['emotion_type'] as num?)?.toInt() ?? 0;
    final notes = (m['notes']?.toString() ?? '').trim();
    final hm = TimeUtils.hm(m['created_at']);
    final head = Row(
      children: [
        Text(
          hm,
          style: TextStyle(
            color: theme.gold,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        XqPigmentDab(
          color: Color(moodColors[score] ?? 0xFF7A7871),
          size: 14,
          seed: score,
        ),
        const SizedBox(width: 6),
        Text(
          moodLabels[score] ?? '',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    if (!lead) {
      return Row(
        children: [
          head,
          if (notes.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: XqTypography.content,
                  fontFamilyFallback: XqTypography.contentFallback,
                  color: theme.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 2),
          _ruled(
            theme,
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                notes,
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
      ],
    );
  }

  /// 本周：一到日七格，记过的那天落一抹颜料，今天下面一笔墨线
  Widget _buildWeek(ThemeState theme, DateTime now) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final recorded = _weekScores.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        XqSectionTitle(
          '本周',
          trailing: Text(
            recorded == 0 ? '还没记过' : '记了${chineseCount(recorded)}天',
            style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
          ),
        ),
        Semantics(
          button: true,
          label: '本周记了$recorded天，去心情页',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openMood,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final d = monday.add(Duration(days: i));
                        final score = _weekScores[key(d)];
                        final isToday =
                            d.day == now.day && d.month == now.month;
                        final future = d.isAfter(now);
                        return Column(
                          children: [
                            Text(
                              names[i],
                              style: XqTypography.headlineSmall.copyWith(
                                color: isToday
                                    ? theme.textPrimary
                                    : theme.textTertiary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 24,
                              child: Center(
                                child: score != null
                                    ? XqPigmentDab(
                                        color: Color(
                                          moodColors[score] ?? 0xFF7A7871,
                                        ),
                                        size: 22,
                                        seed: score + i,
                                      )
                                    : Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: theme.frameColor.withAlpha(
                                            future ? 90 : 255,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 12,
                              height: 1.2,
                              color: isToday
                                  ? theme.textPrimary
                                  : Colors.transparent,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 目录：一行三栏，上下笺框线、栏间界线（不是三张一样的卡片）
  Widget _buildShortcuts(ThemeState theme) {
    Widget entry(XqIcons icon, String title, String sub, Widget page) =>
        Expanded(
          child: Semantics(
            button: true,
            label: '$title，$sub',
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    XqIcon(icon, size: 20, color: theme.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: XqTypography.headlineSmall.copyWith(
                        color: theme.textPrimary,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(color: theme.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    Widget rule() => Container(width: 0.6, height: 44, color: theme.frameColor);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: theme.frameColor, width: 0.6),
        ),
      ),
      child: Row(
        children: [
          entry(XqIcons.book, '素笺', '写长一点的', const StoryListPage()),
          rule(),
          entry(XqIcons.hourglass, '胶囊', '写给以后', const CapsulePage()),
          rule(),
          entry(XqIcons.cards, '卡片册', '做过的卡片', const CardAlbumPage()),
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
                  notes.isEmpty ? '那天只选了心情，没写字。' : notes,
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
              Text(
                '制成卡片',
                style: TextStyle(color: theme.accentColor, fontSize: 13),
              ),
              XqIcon(XqIcons.chevronRight, size: 18, color: theme.accentColor),
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
                  hintText: '搜城市',
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
                  prefixIcon: XqIcon(
                    XqIcons.search,
                    size: 20,
                    color: theme.accentColor,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: XqIcon(XqIcons.close, color: theme.textSecondary),
            ),
          ],
        ),
        if (_citySearchCtrl.text.isNotEmpty && _cityResults.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '没找到这个城市',
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
