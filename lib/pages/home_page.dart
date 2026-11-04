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
import '../utils/weather_utils.dart';
import '../utils/geo_utils.dart';
import '../widgets/jiangnan_scene.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/mood_card_maker.dart';
import '../widgets/stagger_in.dart';
import 'weather_detail_page.dart';

/// 素笺版首页：一屏一主角。
/// 书眉（日期·星期·节气）→ 时段问候 → 今日一行 → 那年今日（偶现）→ 主操作「记一笔」→ 江南远山。
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

  @override
  void initState() {
    super.initState();
    _loadCachedFirst();
    _loadMemory();
  }

  /// 那年今日：往年同月同日最近的一条记录
  Future<void> _loadMemory() async {
    try {
      final data = await Api.getAllMoods();
      final moods = (data['moods'] as List?) ?? const [];
      final now = DateTime.now();
      final suffix =
          '-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      Map<String, dynamic>? best;
      var bestYear = 0;
      for (final m in moods) {
        if (m is! Map) continue;
        final date = m['date']?.toString() ?? '';
        if (!date.endsWith(suffix)) continue;
        final year = int.tryParse(date.substring(0, 4)) ?? 0;
        if (year >= now.year) continue;
        if (year > bestYear) {
          bestYear = year;
          best = Map<String, dynamic>.from(m);
        }
      }
      if (!mounted) return;
      setState(() => _memory = best);
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
          .get(
            Uri.parse('https://whois.pconline.com.cn/ipJson.jsp?json=true'),
          )
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
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
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
    final now = DateTime.now();

    final weekdaysFull = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    final weekday = weekdaysFull[now.weekday == 7 ? 0 : now.weekday];
    final hour = now.hour;
    final greet = hour < 5
        ? '夜深了'
        : hour < 11
            ? '早上好'
            : hour < 14
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : '晚上好';
    final name = appState.displayName.isNotEmpty ? appState.displayName : '朋友';
    final term = currentSolarTerm(now);
    final current =
        _weather != null ? _weather!['current'] as Map<String, dynamic>? : null;
    final cond = current?['weather'];
    final temp = current?['temp_current'];

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWeather,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Stack(
                    children: [
                      // 江南远山：三层淡墨山形，随节气微变
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: JiangnanScenePainter(
                              paper: theme.backgroundColor,
                              accent: theme.accentColor,
                              ink: theme.ink,
                              surface: theme.cardColor,
                              hour: now.hour,
                              seed: now.month * 2 + (now.day > 15 ? 1 : 0),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StaggerIn(
                              index: 0,
                              child: Text(
                                '${now.year}年${now.month}月${now.day}日 · $weekday · $term',
                                style: TextStyle(
                                  color: theme.textTertiary,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            StaggerIn(
                              index: 1,
                              child: Text(
                                '$greet，$name',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 2,
                                  height: 1.2,
                                  fontFamily: 'serif',
                                  fontFamilyFallback: [
                                    'Noto Serif SC',
                                    'Source Han Serif SC',
                                    'Songti SC',
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            StaggerIn(
                              index: 2,
                              child: _buildTodayLine(theme, cond, temp),
                            ),
                            if (_memory != null) ...[
                              const SizedBox(height: 16),
                              StaggerIn(
                                index: 3,
                                child: _buildMemoryLine(theme),
                              ),
                            ],
                            const Spacer(),
                            StaggerIn(
                              index: 4,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: _openWeatherDetail,
                                    child: Text(
                                      '天气详情',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _openCitySheet,
                                    child: Text(
                                      '换城市',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            StaggerIn(
                              index: 5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.accentColor.withAlpha(70),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: _openMood,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: theme.accentColor,
                                      foregroundColor: theme.textOnAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        letterSpacing: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Text('记一笔'),
                                  ),
                                ),
                              ),
                            ),
                            // 远山留白区：山体不与文字重叠
                            const SizedBox(height: 236),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 今日纸片：浮在烟雨山水之上的一枚信息笺
  Widget _buildTodayLine(ThemeState theme, dynamic cond, dynamic temp) {
    final body = _loading && _weather == null
        ? Text('天气正在路上…',
            style: TextStyle(color: theme.textTertiary, fontSize: 15))
        : (cond != null && temp != null)
            ? Text(
                '$cond $temp° · ${_currentCity.isEmpty ? "城市待确认" : _currentCity.split("，").first}',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 15.5,
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            : GestureDetector(
                onTap: _loadWeather,
                child: Text(
                  '天气未取到 · 点按重试',
                  style: TextStyle(color: theme.accentColor, fontSize: 14),
                ),
              );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: theme.cardColor.withAlpha(242),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.borderColor, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: theme.ink.withAlpha(14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: body),
          GestureDetector(
            onTap: _openWeatherDetail,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('详情',
                    style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right_rounded,
                    size: 15, color: theme.accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 那年今日：由卡片降级为一行素笺（点击仍可制卡）
  Widget _buildMemoryLine(ThemeState theme) {
    final m = _memory!;
    final date = m['date']?.toString() ?? '';
    final year = int.tryParse(date.substring(0, 4));
    final yearsAgo = year == null ? '' : '${DateTime.now().year - year}年前';
    final score = (m['emotion_type'] as num?)?.toInt() ?? 0;
    final emoji = moodEmojis[score] ?? '';
    final code = int.tryParse(m['weather_code']?.toString() ?? '');
    final weatherText = weatherTextForCode(code);
    final notes = (m['notes']?.toString() ?? '').trim();

    return GestureDetector(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor.withAlpha(242),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.borderColor.withAlpha(120), width: 0.6),
          boxShadow: [
            BoxShadow(
              color: theme.ink.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '那年今日$yearsAgo —— ${notes.isEmpty ? "只留下了一个心情" : notes}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
            ),
            if (weatherText.isNotEmpty)
              Text(
                weatherText,
                style: TextStyle(color: theme.gold, fontSize: 11.5),
              ),
          ],
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

/// 江南远山：三层淡墨山形，随节气微变轮廓。
/// 颜色只取主题 ink（低透明度分层表现远近），深浅主题自然成立。

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
