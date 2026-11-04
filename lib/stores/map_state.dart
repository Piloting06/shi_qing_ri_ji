import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';
import '../constants/keys.dart';
import '../utils/geo_utils.dart' show haversineKm, findNearestCity;
import '../models/city.dart';

/// 城市数据（精简）
class CityData {
  final String code;
  final String name;
  final String province;
  final double lat;
  final double lng;
  final int level; // 1=省会 2=地级 3=县级

  const CityData({
    required this.code,
    required this.name,
    required this.province,
    required this.lat,
    required this.lng,
    required this.level,
  });

  @override
  bool operator ==(Object other) => other is CityData && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class MapState extends ChangeNotifier {
  // ── 加载状态 ──
  bool _loading = true;
  String? _error;

  // ── 定位 ──
  CityData? _myCity;
  bool _locating = true;
  String? _locationError;

  // ── 选中城市 ──
  CityData? _selectedCity;
  String? _selectedCityCode;
  List<Map<String, dynamic>> _comments = [];
  int _commentPage = 1;
  bool _commentLoading = false;
  bool _commentHasMore = true;

  // ── 城市统计 ──
  final Map<String, int> _cityCommentCounts = {};
  final Map<String, String> _cityMoods = {};
  final Map<String, double> _cityMoodScore = {};

  // ── 动画 / 轮询 ──
  bool _introPlayed = false;
  Timer? _pollTimer;
  bool _isVisible = false;

  // ── 全部城市坐标（硬编码，无需外部加载） ──
  static const _allCities = <CityData>[
    CityData(
      code: '110000',
      name: '北京',
      province: '北京',
      lat: 39.91,
      lng: 116.40,
      level: 1,
    ),
    CityData(
      code: '120000',
      name: '天津',
      province: '天津',
      lat: 39.13,
      lng: 117.19,
      level: 1,
    ),
    CityData(
      code: '310000',
      name: '上海',
      province: '上海',
      lat: 31.23,
      lng: 121.47,
      level: 1,
    ),
    CityData(
      code: '500000',
      name: '重庆',
      province: '重庆',
      lat: 29.56,
      lng: 106.55,
      level: 1,
    ),
    CityData(
      code: '130100',
      name: '石家庄',
      province: '河北',
      lat: 38.04,
      lng: 114.51,
      level: 1,
    ),
    CityData(
      code: '140100',
      name: '太原',
      province: '山西',
      lat: 37.87,
      lng: 112.55,
      level: 1,
    ),
    CityData(
      code: '150100',
      name: '呼和浩特',
      province: '内蒙古',
      lat: 40.84,
      lng: 111.75,
      level: 1,
    ),
    CityData(
      code: '210100',
      name: '沈阳',
      province: '辽宁',
      lat: 41.80,
      lng: 123.43,
      level: 1,
    ),
    CityData(
      code: '220100',
      name: '长春',
      province: '吉林',
      lat: 43.88,
      lng: 125.32,
      level: 1,
    ),
    CityData(
      code: '230100',
      name: '哈尔滨',
      province: '黑龙江',
      lat: 45.80,
      lng: 126.53,
      level: 1,
    ),
    CityData(
      code: '320100',
      name: '南京',
      province: '江苏',
      lat: 32.06,
      lng: 118.80,
      level: 1,
    ),
    CityData(
      code: '330100',
      name: '杭州',
      province: '浙江',
      lat: 30.27,
      lng: 120.15,
      level: 1,
    ),
    CityData(
      code: '340100',
      name: '合肥',
      province: '安徽',
      lat: 31.86,
      lng: 117.28,
      level: 1,
    ),
    CityData(
      code: '350100',
      name: '福州',
      province: '福建',
      lat: 26.07,
      lng: 119.30,
      level: 1,
    ),
    CityData(
      code: '360100',
      name: '南昌',
      province: '江西',
      lat: 28.68,
      lng: 115.89,
      level: 1,
    ),
    CityData(
      code: '370100',
      name: '济南',
      province: '山东',
      lat: 36.67,
      lng: 116.98,
      level: 1,
    ),
    CityData(
      code: '410100',
      name: '郑州',
      province: '河南',
      lat: 34.75,
      lng: 113.63,
      level: 1,
    ),
    CityData(
      code: '420100',
      name: '武汉',
      province: '湖北',
      lat: 30.59,
      lng: 114.31,
      level: 1,
    ),
    CityData(
      code: '430100',
      name: '长沙',
      province: '湖南',
      lat: 28.23,
      lng: 112.94,
      level: 1,
    ),
    CityData(
      code: '440100',
      name: '广州',
      province: '广东',
      lat: 23.13,
      lng: 113.26,
      level: 1,
    ),
    CityData(
      code: '450100',
      name: '南宁',
      province: '广西',
      lat: 22.82,
      lng: 108.37,
      level: 1,
    ),
    CityData(
      code: '460100',
      name: '海口',
      province: '海南',
      lat: 20.02,
      lng: 110.35,
      level: 1,
    ),
    CityData(
      code: '510100',
      name: '成都',
      province: '四川',
      lat: 30.57,
      lng: 104.07,
      level: 1,
    ),
    CityData(
      code: '520100',
      name: '贵阳',
      province: '贵州',
      lat: 26.65,
      lng: 106.63,
      level: 1,
    ),
    CityData(
      code: '530100',
      name: '昆明',
      province: '云南',
      lat: 25.04,
      lng: 102.71,
      level: 1,
    ),
    CityData(
      code: '540100',
      name: '拉萨',
      province: '西藏',
      lat: 29.65,
      lng: 91.13,
      level: 1,
    ),
    CityData(
      code: '610100',
      name: '西安',
      province: '陕西',
      lat: 34.26,
      lng: 108.94,
      level: 1,
    ),
    CityData(
      code: '620100',
      name: '兰州',
      province: '甘肃',
      lat: 36.06,
      lng: 103.83,
      level: 1,
    ),
    CityData(
      code: '630100',
      name: '西宁',
      province: '青海',
      lat: 36.62,
      lng: 101.78,
      level: 1,
    ),
    CityData(
      code: '640100',
      name: '银川',
      province: '宁夏',
      lat: 38.47,
      lng: 106.27,
      level: 1,
    ),
    CityData(
      code: '650100',
      name: '乌鲁木齐',
      province: '新疆',
      lat: 43.83,
      lng: 87.62,
      level: 1,
    ),
    CityData(
      code: '810000',
      name: '香港',
      province: '香港',
      lat: 22.32,
      lng: 114.17,
      level: 1,
    ),
    CityData(
      code: '820000',
      name: '澳门',
      province: '澳门',
      lat: 22.20,
      lng: 113.55,
      level: 1,
    ),
    CityData(
      code: '710000',
      name: '台北',
      province: '台湾',
      lat: 25.03,
      lng: 121.57,
      level: 1,
    ),
    // 重要地级市
    CityData(
      code: '370200',
      name: '青岛',
      province: '山东',
      lat: 36.07,
      lng: 120.38,
      level: 2,
    ),
    CityData(
      code: '330200',
      name: '宁波',
      province: '浙江',
      lat: 29.87,
      lng: 121.54,
      level: 2,
    ),
    CityData(
      code: '350200',
      name: '厦门',
      province: '福建',
      lat: 24.48,
      lng: 118.09,
      level: 2,
    ),
    CityData(
      code: '440300',
      name: '深圳',
      province: '广东',
      lat: 22.54,
      lng: 114.06,
      level: 2,
    ),
    CityData(
      code: '210200',
      name: '大连',
      province: '辽宁',
      lat: 38.91,
      lng: 121.61,
      level: 2,
    ),
    CityData(
      code: '320500',
      name: '苏州',
      province: '江苏',
      lat: 31.30,
      lng: 120.58,
      level: 2,
    ),
    CityData(
      code: '360400',
      name: '九江',
      province: '江西',
      lat: 29.71,
      lng: 116.00,
      level: 2,
    ),
    CityData(
      code: '360700',
      name: '赣州',
      province: '江西',
      lat: 25.83,
      lng: 114.93,
      level: 2,
    ),
    CityData(
      code: '360200',
      name: '景德镇',
      province: '江西',
      lat: 29.27,
      lng: 117.18,
      level: 2,
    ),
    CityData(
      code: '320200',
      name: '无锡',
      province: '江苏',
      lat: 31.57,
      lng: 120.31,
      level: 2,
    ),
    CityData(
      code: '441900',
      name: '东莞',
      province: '广东',
      lat: 23.02,
      lng: 113.75,
      level: 2,
    ),
    CityData(
      code: '440600',
      name: '佛山',
      province: '广东',
      lat: 23.02,
      lng: 113.12,
      level: 2,
    ),
    CityData(
      code: '350500',
      name: '泉州',
      province: '福建',
      lat: 24.87,
      lng: 118.67,
      level: 2,
    ),
    CityData(
      code: '430200',
      name: '株洲',
      province: '湖南',
      lat: 27.83,
      lng: 113.13,
      level: 2,
    ),
    CityData(
      code: '450300',
      name: '桂林',
      province: '广西',
      lat: 25.23,
      lng: 110.18,
      level: 2,
    ),
    CityData(
      code: '460200',
      name: '三亚',
      province: '海南',
      lat: 18.25,
      lng: 109.51,
      level: 2,
    ),
    CityData(
      code: '520300',
      name: '遵义',
      province: '贵州',
      lat: 27.72,
      lng: 106.93,
      level: 2,
    ),
    CityData(
      code: '420500',
      name: '宜昌',
      province: '湖北',
      lat: 30.69,
      lng: 111.29,
      level: 2,
    ),
    CityData(
      code: '410300',
      name: '洛阳',
      province: '河南',
      lat: 34.62,
      lng: 112.45,
      level: 2,
    ),
    CityData(
      code: '610300',
      name: '宝鸡',
      province: '陕西',
      lat: 34.36,
      lng: 107.24,
      level: 2,
    ),
    CityData(
      code: '620200',
      name: '嘉峪关',
      province: '甘肃',
      lat: 39.77,
      lng: 98.29,
      level: 2,
    ),
    CityData(
      code: '530500',
      name: '保山',
      province: '云南',
      lat: 25.11,
      lng: 99.17,
      level: 2,
    ),
    CityData(
      code: '540200',
      name: '日喀则',
      province: '西藏',
      lat: 29.27,
      lng: 88.88,
      level: 2,
    ),
    CityData(
      code: '652300',
      name: '昌吉',
      province: '新疆',
      lat: 44.01,
      lng: 87.31,
      level: 2,
    ),
    CityData(
      code: '450200',
      name: '柳州',
      province: '广西',
      lat: 24.31,
      lng: 109.41,
      level: 2,
    ),
    CityData(
      code: '330700',
      name: '金华',
      province: '浙江',
      lat: 29.08,
      lng: 119.65,
      level: 2,
    ),
    CityData(
      code: '371300',
      name: '临沂',
      province: '山东',
      lat: 35.10,
      lng: 118.35,
      level: 2,
    ),
    CityData(
      code: '411300',
      name: '南阳',
      province: '河南',
      lat: 32.99,
      lng: 112.53,
      level: 2,
    ),
    CityData(
      code: '360800',
      name: '吉安',
      province: '江西',
      lat: 27.11,
      lng: 114.99,
      level: 2,
    ),
  ];

  // ── Getters ──
  bool get loading => _loading;
  String? get error => _error;
  CityData? get myCity => _myCity;
  bool get locating => _locating;
  String? get locationError => _locationError;
  CityData? get selectedCity => _selectedCity;
  String? get selectedCityCode => _selectedCityCode;
  List<Map<String, dynamic>> get comments => _comments;
  bool get commentLoading => _commentLoading;
  bool get commentHasMore => _commentHasMore;
  Map<String, int> get cityCommentCounts => _cityCommentCounts;
  Map<String, String> get cityMoods => _cityMoods;
  String? cityMood(String code) => _cityMoods[code];
  double cityMoodScore(String code) => _cityMoodScore[code] ?? 0;
  int cityCommentCount(String code) => _cityCommentCounts[code] ?? 0;
  double? distanceTo(CityData target) {
    if (_myCity == null) return null;
    return haversineKm(_myCity!.lat, _myCity!.lng, target.lat, target.lng);
  }
  bool get introPlayed => _introPlayed;
  bool get isVisible => _isVisible;
  List<CityData> get allCities => _allCities;
  static const List<CityData> allCityList = _allCities;

  bool get canPost {
    if (_myCity == null || _selectedCity == null) return false;
    return _myCity!.code == _selectedCity!.code;
  }

  /// 地图缩放级别转 LOD
  int projectionLod() => 1; // flutter_map 下始终显示地级市

  /// 初始化
  Future<void> initialize() async {
    if (!_loading) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _introPlayed = prefs.getBool('mapFirstOpen') ?? false;

      // 1. 加载缓存
      final cachedJson = prefs.getString(StorageKeys.mapStatsCache);
      if (cachedJson != null) {
        try {
          final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
          final timestamp = cached['timestamp'] as int? ?? 0;
          if (DateTime.now().millisecondsSinceEpoch - timestamp < 30 * 60 * 1000) {
            final stats = cached['data'] as Map<String, dynamic>?;
            if (stats != null) {
              for (final e in stats.entries) {
                final d = e.value as Map<String, dynamic>?;
                if (d == null) continue;
                _cityCommentCounts[e.key] = d['count'] as int? ?? 0;
                _cityMoods[e.key] = d['mood'] as String? ?? '';
                _cityMoodScore[e.key] = (d['mood_score'] as num?)?.toDouble() ?? 0.0;
              }
              _loading = false;
              notifyListeners();
              await _locate();
              _pollStats(); // 后台刷新
              return;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    _loading = false;
    notifyListeners();
    await _locate();
    _pollStats();
  }

  /// 强制刷新（下拉刷新用）
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    await _locate();
    _loading = false;
    notifyListeners();
    await _pollStats();
  }

  /// GPS 定位（多级回退：首页缓存 → GPS+内置列表 → IP定位）
  Future<void> _locate() async {
    _locating = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. 先读首页写入的位置缓存
      var lat = prefs.getDouble('weather_lat');
      var lng = prefs.getDouble('weather_lon');
      if (lat != null && lng != null) {
        final city = _cityFromGeo(findNearestCity(lat, lng, maxKm: 100));
        if (city != null) {
          _myCity = city;
          _locating = false;
          _locationError = null;
          notifyListeners();
          return;
        }
      }

      // 2. 再读城迹自己的缓存
      lat = prefs.getDouble('cityLat');
      lng = prefs.getDouble('cityLon');
      if (lat != null && lng != null) {
        final city = _cityFromGeo(findNearestCity(lat, lng, maxKm: 100));
        if (city != null) {
          _myCity = city;
          _locating = false;
          _locationError = null;
          notifyListeners();
          return;
        }
      }

      // 3. GPS with proper permission handling
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _locationError = '系统定位未开启';
          notifyListeners();
        } else {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.deniedForever) {
            _locationError = '定位权限已被永久拒绝，请在系统设置中开启';
            notifyListeners();
          } else {
            if (permission == LocationPermission.denied) {
              await Geolocator.requestPermission();
            }
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 12),
              ),
            );
            final city = _cityFromGeo(
              findNearestCity(pos.latitude, pos.longitude, maxKm: 100),
            );
            if (city != null) {
              _myCity = city;
              _locating = false;
              _locationError = null;
              await prefs.setDouble('cityLat', pos.latitude);
              await prefs.setDouble('cityLon', pos.longitude);
              notifyListeners();
              return;
            }
          }
        }
      } catch (e) {
        _locationError = '手机定位没成功，正在按网络大致定位';
        notifyListeners();
      }

      // 4. IP 定位兜底（客户端直连 ip-api；走服务端会解析到服务器所在城市）
      try {
        final res = await http
            .get(
              Uri.parse(
                'http://ip-api.com/json/?fields=status,lat,lon,city,regionName,country&lang=zh',
              ),
            )
            .timeout(const Duration(seconds: 5));
        final j = json.decode(res.body);
        if (j is Map && j['status'] == 'success' && j['lat'] != null && j['lon'] != null) {
          final ipLat = (j['lat'] as num).toDouble();
          final ipLng = (j['lon'] as num).toDouble();
          final city = _cityFromGeo(findNearestCity(ipLat, ipLng, maxKm: 200));
          if (city != null) {
            _myCity = city;
            _locating = false;
            _locationError = null;
            await prefs.setDouble('cityLat', ipLat);
            await prefs.setDouble('cityLon', ipLng);
            notifyListeners();
            return;
          }
        }
      } catch (_) {}

      _locationError = '无法定位，可搜索城市';
    } catch (_) {
      _locationError = '定位失败';
    }
    _locating = false;
    notifyListeners();
  }

  CityData? _cityFromGeo(City? c) {
    if (c == null) return null;
    return CityData(
      code: c.code,
      name: c.name,
      province: c.province,
      lat: c.lat,
      lng: c.lng,
      level: c.level,
    );
  }

  CityData? searchCity(String q) {
    if (q.trim().isEmpty) return null;
    final lower = q.trim().toLowerCase();
    for (final c in _allCities) {
      if (c.name.toLowerCase().contains(lower) ||
          c.province.toLowerCase().contains(lower)) {
        return c;
      }
    }
    return null;
  }

  /// 面板关闭后刷新
  void refreshCards() {
    _pollStats();
    notifyListeners();
  }

  /// 选择城市
  void selectCityCode(String code) {
    _selectedCity = _allCities.cast<CityData?>().firstWhere(
      (c) => c?.code == code,
      orElse: () => null,
    );
    _selectedCityCode = code;
    _comments = [];
    _commentPage = 1;
    _commentHasMore = true;
    notifyListeners();
    _loadComments();
  }

  Future<void> _loadComments() async {
    if (_selectedCityCode == null || _commentLoading || !_commentHasMore) {
      return;
    }
    _commentLoading = true;
    notifyListeners();
    try {
      final data = await Api.getCityComments(
        _selectedCityCode!,
        page: _commentPage,
      );
      final list = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      _comments = _commentPage == 1 ? list : [..._comments, ...list];
      _commentHasMore = list.length >= 20;
      _commentPage++;
    } catch (_) {}
    _commentLoading = false;
    notifyListeners();
  }

  void loadMoreComments() => _loadComments();

  Future<({bool ok, String message})> postComment(String content) async {
    if (_selectedCityCode == null) return (ok: false, message: '未选择城市');
    try {
      final data = await Api.postCityComment(_selectedCityCode!, content);
      _comments.insert(0, {
        'id': data['id'],
        'content': content,
        'likes': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_own': true,
      });
      _cityCommentCounts[_selectedCityCode!] =
          (_cityCommentCounts[_selectedCityCode!] ?? 0) + 1;
      notifyListeners();
      return (ok: true, message: '足迹已留下');
    } on ApiException catch (e) {
      return (ok: false, message: e.message);
    } catch (_) {
      return (ok: false, message: '网络不太好，稍后再发吧');
    }
  }

  Future<void> likeComment(int id) async {
    try {
      await Api.likeCityComment(id);
      final i = _comments.indexWhere((c) => c['id'] == id);
      if (i >= 0) {
        _comments[i] = Map<String, dynamic>.from(_comments[i])
          ..['likes'] = (_comments[i]['likes'] ?? 0) + 1
          ..['liked'] = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> deleteComment(int id) async {
    try {
      await Api.deleteCityComment(id);
      _comments.removeWhere((c) => c['id'] == id);
      if (_selectedCityCode != null) {
        _cityCommentCounts[_selectedCityCode!] =
            (_cityCommentCounts[_selectedCityCode!] ?? 1) - 1;
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void markIntroDone() {
    _introPlayed = true;
    SharedPreferences.getInstance().then(
      (p) => p.setBool('mapFirstOpen', true),
    );
    notifyListeners();
  }

  void setVisible(bool v) {
    _isVisible = v;
    v ? _startPolling() : _stopPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollStats();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _pollStats(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollStats() async {
    try {
      final data = await Api.getCityStats();
      final stats = data['stats'] as Map<String, dynamic>?;
      if (stats == null) return;
      bool changed = false;
      for (final e in stats.entries) {
        final d = e.value as Map<String, dynamic>?;
        if (d == null) continue;
        final c = d['count'] as int? ?? 0;
        final m = d['mood'] as String?;
        final s = (d['mood_score'] as num?)?.toDouble();
        if (_cityCommentCounts[e.key] != c) {
          _cityCommentCounts[e.key] = c;
          changed = true;
        }
        if (m != null) _cityMoods[e.key] = m;
        if (s != null) _cityMoodScore[e.key] = s;
      }
      if (changed) notifyListeners();

      // 保存缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(StorageKeys.mapStatsCache, jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': data['stats'],
        }));
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> retry() async {
    _loading = true;
    _error = null;
    _locating = true;
    _locationError = null;
    notifyListeners();
    await initialize();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
