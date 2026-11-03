import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../constants/mood.dart';
import '../stores/map_state.dart';
import '../stores/theme_state.dart';
import '../widgets/city_comment_sheet.dart';
import '../widgets/xq/xq_icons.dart';
import '../theme/xq_typography.dart';
import '../widgets/xq_toast.dart';
import '../data/city_intro_data.dart';

class CityMapPage extends StatefulWidget {
  const CityMapPage({super.key});
  @override
  State<CityMapPage> createState() => _CityMapPageState();
}

class _CityMapPageState extends State<CityMapPage>
    with AutomaticKeepAliveClientMixin {
  late MapState _map;
  String _search = '';
  String _moodFilter = 'all';
  String _sortBy = 'hot';
  final _searchCtrl = TextEditingController();
  Future<Map<String, dynamic>?>? _moodboard;

  Future<Map<String, dynamic>?> _loadMoodboard() async {
    try {
      return await Api.getCityMoodboard();
    } catch (_) {
      return null;
    }
  }

  static const _filterOptions = [
    ('all', '全部', null),
    ('warm', '温暖', 'warm'),
    ('sad', '忧伤', 'sad'),
    ('calm', '平静', 'calm'),
    ('anxious', '焦虑', 'anxious'),
    ('excited', '兴奋', 'excited'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _map = context.read<MapState>();
    _moodboard = _loadMoodboard();
    WidgetsBinding.instance.addPostFrameCallback((_) => _map.initialize());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.watch<ThemeState>();
    final map = context.watch<MapState>();

    if (map.loading) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                '正在看各城的天气与心情…',
                style: TextStyle(color: theme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final allCities = List<CityData>.from(MapState.allCityList);
    if (map.myCity != null) allCities.remove(map.myCity);

    // Sort
    _sortCities(allCities, map);
    if (map.myCity != null) allCities.insert(0, map.myCity!);

    // Filter by search
    var filtered = _search.trim().isEmpty
        ? allCities
        : allCities
            .where((c) =>
                c.name.contains(_search.trim()) ||
                c.province.contains(_search.trim()))
            .toList();

    // Filter by mood
    if (_moodFilter != 'all') {
      filtered =
          filtered.where((c) => map.cityMood(c.code) == _moodFilter).toList();
    }

    final browsing = _search.trim().isEmpty && _moodFilter == 'all';
    final activeCities =
        filtered.where((c) => map.cityCommentCount(c.code) > 0).toList();
    final quietCities =
        filtered.where((c) => map.cityCommentCount(c.code) == 0).toList();

    SliverList cityList(List<CityData> cities) => SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _cityRow(cities[i], map, theme, last: i == cities.length - 1),
            childCount: cities.length,
          ),
        );

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _map.refresh();
            final f = _loadMoodboard();
            setState(() => _moodboard = f);
            await f;
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _pageHeader(theme)),
              SliverToBoxAdapter(child: _searchBar(theme)),
              SliverToBoxAdapter(child: _filterChips(map, theme)),
              if (browsing) SliverToBoxAdapter(child: _statsHeader(map, theme)),
              if (browsing) SliverToBoxAdapter(child: _moodboardSection(theme)),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptySearch(theme),
                )
              else if (!browsing)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: cityList(filtered),
                )
              else ...[
                if (activeCities.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _sectionTitle(theme, '正在说话的城市', activeCities.length),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: cityList(activeCities),
                  ),
                ],
                if (quietCities.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _sectionTitle(theme, '还在等第一个人', quietCities.length),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: cityList(quietCities),
                  ),
                ],
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _buildFooter(map, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
      child: Row(
        children: [
          Text(
            '城迹',
            style: XqTypography.displayMedium.copyWith(color: theme.textPrimary),
          ),
          const SizedBox(width: 12),
          Text(
            '各城此刻的心情',
            style: TextStyle(color: theme.textTertiary, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            tooltip: '排序',
            onPressed: () => _showSortSheet(theme),
            icon: Icon(Icons.sort_rounded, color: theme.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeState theme, String title, int n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: XqTypography.headlineSmall.copyWith(color: theme.textPrimary),
          ),
          const Spacer(),
          Text(
            '$n 座',
            style: TextStyle(color: theme.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Sorting ──

  void _sortCities(List<CityData> cities, MapState map) {
    switch (_sortBy) {
      case 'hot':
        cities.sort((a, b) => map
            .cityCommentCount(b.code)
            .compareTo(map.cityCommentCount(a.code)));
      case 'near':
        if (map.myCity != null) {
          cities.sort((a, b) {
            final da = map.distanceTo(a) ?? 99999;
            final db = map.distanceTo(b) ?? 99999;
            return da.compareTo(db);
          });
        }
      case 'alpha':
        cities.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  // ── Filter：文字 + 选中下划线（与登录页切换同一语言）──

  Widget _filterChips(MapState map, ThemeState theme) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: _filterOptions.map((opt) {
          final (key, label, _) = opt;
          final active = _moodFilter == key;
          final color = key != 'all' ? _moodColor(key) : theme.accentColor;
          return Semantics(
            button: true,
            selected: active,
            label: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _moodFilter = key);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (key != 'all') ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: active ? theme.textPrimary : theme.textTertiary,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 16 : 0,
                      height: 1.5,
                      color: theme.accentColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 城市心晴榜：排名文字，无底卡 ──

  Widget _moodboardSection(ThemeState theme) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _moodboard,
      builder: (context, snap) {
        final board =
            (snap.data?['board'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (board.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '城市心晴榜',
                    style: XqTypography.headlineSmall
                        .copyWith(color: theme.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '最近七天',
                    style: TextStyle(color: theme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: board.length,
                separatorBuilder: (_, _) => Container(
                  width: 0.8,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: theme.borderColor,
                ),
                itemBuilder: (context, i) {
                  final item = board[i];
                  final city = (item['city']?.toString() ?? '').split('，').first;
                  final mood = (item['top_mood'] as num?)?.toInt() ?? 0;
                  final count = (item['count'] as num?)?.toInt() ?? 0;
                  final color = Color(moodColors[mood] ?? 0xFF7C918C);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: i < 3 ? theme.gold : theme.textTertiary,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city,
                            style: XqTypography.headlineSmall.copyWith(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${moodLabels[mood] ?? ''} · $count 笔',
                                style: TextStyle(
                                  color: theme.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _searchBar(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        style: TextStyle(color: theme.textPrimary, fontSize: 15),
        cursorColor: theme.accentColor,
        decoration: InputDecoration(
          hintText: '找一座城市',
          isDense: true,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: XqIcon(XqIcons.search, size: 18, color: theme.textTertiary),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  tooltip: '清空',
                  icon: XqIcon(XqIcons.close, size: 16, color: theme.textTertiary),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── Sort Sheet ──

  void _showSortSheet(ThemeState theme) {
    final options = [
      ('hot', '足迹最多'),
      ('near', '离我最近'),
      ('alpha', '按名称'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '排序',
                style: XqTypography.headlineSmall.copyWith(color: theme.textPrimary),
              ),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final (key, label) = opt;
                final active = _sortBy == key;
                return ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      color: active ? theme.accentColor : theme.textPrimary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: active
                      ? Icon(Icons.check, size: 18, color: theme.accentColor)
                      : null,
                  onTap: () {
                    setState(() => _sortBy = key);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── 所在城市：一行字 + 写足迹 ──

  Widget _statsHeader(MapState map, ThemeState theme) {
    final myCity = map.myCity;
    final totalActive = MapState.allCityList
        .where((c) => map.cityCommentCount(c.code) > 0)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  myCity != null ? '你在${myCity.name}' : '还不知道你在哪座城',
                  style: TextStyle(color: theme.textPrimary, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  totalActive > 0
                      ? '$totalActive 座城市有人在说话'
                      : '各城都还安静，做第一个说话的人',
                  style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (myCity != null)
            TextButton(
              onPressed: () {
                map.selectCityCode(myCity.code);
                CityCommentSheet.show(context);
              },
              child: const Text('写足迹'),
            ),
        ],
      ),
    );
  }

  // ── 城市行：宋体城名 + 省份距离 + 一句气质；右侧足迹数与釉色点 ──

  Widget _cityRow(CityData city, MapState map, ThemeState theme, {required bool last}) {
    final isMe = map.myCity != null && map.myCity!.code == city.code;
    final count = map.cityCommentCount(city.code);
    final mood = map.cityMood(city.code);
    final hasActivity = count > 0;
    final dist = map.distanceTo(city);
    final intro = CityIntroData.get(city.code);

    String? distStr;
    if (dist != null) {
      if (dist < 1) {
        distStr = '1km 内';
      } else if (dist >= 1000) {
        distStr = '${(dist / 1000).toStringAsFixed(1)}千公里';
      } else {
        distStr = '${dist.toStringAsFixed(0)}km';
      }
    }
    final meta = [
      city.province,
      ?distStr,
      if (intro != null) ...intro.tags.take(2),
    ].join(' · ');
    final line = hasActivity
        ? (intro?.vibe ?? _moodLine(mood, city.name, count))
        : (intro?.vibe ?? '还在等第一个说话的人');

    return Semantics(
      button: true,
      label: '${city.name}${hasActivity ? '，$count 条足迹' : ''}',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          map.selectCityCode(city.code);
          CityCommentSheet.show(context);
        },
        onLongPress: () {
          if (intro == null) return;
          HapticFeedback.mediumImpact();
          XqToast.info(context, '${city.name} · ${intro.vibe}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: theme.borderColor, width: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          city.name,
                          style: XqTypography.headlineLarge.copyWith(
                            color: theme.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          Text(
                            '所在',
                            style: TextStyle(
                              color: theme.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasActivity ? theme.textSecondary : theme.textTertiary,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: hasActivity
                    ? Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _moodColor(mood),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 15,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      )
                    : Icon(Icons.chevron_right, size: 18, color: theme.borderColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty Search ──

  Widget _emptySearch(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Text(
            '没找到这座城市',
            style: TextStyle(color: theme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Footer ──

  Widget _buildFooter(MapState map, ThemeState theme) {
    final total = MapState.allCityList.length;
    final quotes = [
      '$total 座城市 · 每座都有人在想事情',
      '$total 座城市 · 此刻有人和你看同一片天',
      '$total 座城市 · 总有一座懂你的心情',
      '$total 座城市 · 今天你在哪里？',
    ];
    final quote = quotes[DateTime.now().day % quotes.length];

    final quietCities = MapState.allCityList
        .where((c) => map.cityCommentCount(c.code) == 0)
        .toList();
    final showEgg = quietCities.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch % 3 == 0;
    final eggCity = showEgg
        ? quietCities[DateTime.now().day % quietCities.length]
        : null;

    return Column(
      children: [
        if (eggCity != null) ...[
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              map.selectCityCode(eggCity.code);
              CityCommentSheet.show(context);
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '也许你想去${eggCity.name}看看',
                style: TextStyle(color: theme.accentColor, fontSize: 13),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            quote,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textTertiary, fontSize: 11),
          ),
        ),
      ],
    );
  }

  // ── Mood Colors ──

  /// 城市情绪 → 心情釉色（取 constants/mood.dart，不另起色值）
  Color _moodColor(String? mood) {
    final score = switch (mood) {
      'warm' => 1, // 开心
      'sad' => 3, // 难过
      'anxious' => 5, // 焦虑
      'calm' => 2, // 平静
      'excited' => 7, // 期待
      _ => 2,
    };
    return Color(moodColors[score]!);
  }

  String _moodLine(String? mood, String name, int count) {
    if (count > 0 && mood == null) return '有人在$name留下了足迹';
    return switch (mood) {
      'warm' => '有人在这里被陌生人撑了伞',
      'sad' => '凌晨的$name，有人在想家',
      'anxious' => '这里的人说「干就完了」',
      'calm' => '有人坐在街边发了一下午呆',
      'excited' => '昨晚有人在这里庆祝到凌晨',
      _ => '$name还在等第一个说话的人',
    };
  }
}
