import 'package:flutter/material.dart';
import '../widgets/xq/xq_kit.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../constants/mood.dart';
import '../stores/map_state.dart';
import '../stores/theme_state.dart';
import '../widgets/city_comment_sheet.dart';
import '../widgets/xq/xq_icons.dart';
import '../widgets/xq/xq_surface.dart';
import '../widgets/xq/xq_paper.dart';
import '../theme/xq_decorations.dart';
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
        body: XqPaperPage(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 20, height: 20, child: XqInkLoader()),
                const SizedBox(height: 16),
                Text(
                  '正在翻各城的足迹…',
                  style: TextStyle(color: theme.textSecondary, fontSize: 14),
                ),
              ],
            ),
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
              .where(
                (c) =>
                    c.name.contains(_search.trim()) ||
                    c.province.contains(_search.trim()),
              )
              .toList();

    // Filter by mood
    if (_moodFilter != 'all') {
      filtered = filtered
          .where((c) => map.cityMood(c.code) == _moodFilter)
          .toList();
    }

    final browsing = _search.trim().isEmpty && _moodFilter == 'all';
    final activeCities = filtered
        .where((c) => map.cityCommentCount(c.code) > 0)
        .toList();
    final quietCities = filtered
        .where((c) => map.cityCommentCount(c.code) == 0)
        .toList();

    // 整段城市列表装进一张卡（L1），行间内缩细线
    Widget cityList(List<CityData> cities) => DecoratedSliver(
      decoration: XqDecorations.surface(
        theme.cardColor,
        dark: theme.isDark,
        edge: theme.frameColor,
        grain: XqPaper.grain(
          theme.paperFiber,
          strength: theme.isDark ? 0.6 : 0.8,
        ),
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) =>
                _cityRow(cities[i], map, theme, last: i == cities.length - 1),
            childCount: cities.length,
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: XqPaperPage(
        child: SafeArea(
          child: XqRefresh(
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
                if (browsing)
                  SliverToBoxAdapter(child: _statsHeader(map, theme)),
                if (browsing)
                  SliverToBoxAdapter(child: _moodboardSection(theme)),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptySearch(theme),
                  )
                else if (!browsing)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: cityList(filtered),
                  )
                else ...[
                  if (activeCities.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _sectionTitle(theme, '有人写过', activeCities.length),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: cityList(activeCities),
                    ),
                  ],
                  if (quietCities.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _sectionTitle(theme, '还没人写', quietCities.length),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
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
      ),
    );
  }

  Widget _pageHeader(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '城迹',
                style: XqTypography.displayMedium.copyWith(
                  color: theme.textPrimary,
                  fontSize: 32,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '各地的人，今天写了什么',
                style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: '排序',
            onPressed: () => _showSortSheet(theme),
            icon: XqIcon(XqIcons.tune, color: theme.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeState theme, String title, int n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: XqSectionTitle(
        title,
        trailing: Text(
          '$n 座',
          style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
        ),
      ),
    );
  }

  // ── Sorting ──

  void _sortCities(List<CityData> cities, MapState map) {
    switch (_sortBy) {
      case 'hot':
        cities.sort(
          (a, b) => map
              .cityCommentCount(b.code)
              .compareTo(map.cityCommentCount(a.code)),
        );
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
                          XqPigmentDab(
                            color: color,
                            size: 11,
                            seed: key.length,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: active
                                ? theme.textPrimary
                                : theme.textTertiary,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 16 : 0,
                      height: 1.2,
                      color: theme.textPrimary,
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

  // ── 心晴榜：张榜。一张笺上五列，竖排城名，汉字名次，栏间界线 ──

  Widget _moodboardSection(ThemeState theme) {
    const ranks = ['一', '二', '三', '四', '五'];
    return FutureBuilder<Map<String, dynamic>?>(
      future: _moodboard,
      builder: (context, snap) {
        final board =
            ((snap.data?['board'] as List?)?.cast<Map<String, dynamic>>() ?? [])
                .take(5)
                .toList();
        if (board.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              XqSectionTitle('心晴榜', caption: '近七天，写得最多的城'),
              XqSurface(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < board.length; i++) ...[
                        if (i > 0)
                          Container(width: 0.6, color: theme.borderColor),
                        Expanded(
                          child: _boardColumn(theme, board[i], ranks[i], i),
                        ),
                      ],
                      for (var i = board.length; i < 5; i++) ...[
                        Container(width: 0.6, color: theme.borderColor),
                        const Expanded(child: SizedBox()),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _boardColumn(
    ThemeState theme,
    Map<String, dynamic> item,
    String rank,
    int i,
  ) {
    final city = (item['city']?.toString() ?? '').split('，').first;
    final mood = (item['top_mood'] as num?)?.toInt() ?? 0;
    final count = (item['count'] as num?)?.toInt() ?? 0;
    return Semantics(
      label: '第$rank，$city，多是${moodLabels[mood] ?? ''}，$count 笔',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            rank,
            style: XqTypography.headlineSmall.copyWith(
              color: i < 3 ? theme.gold : theme.textTertiary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final ch in city.characters.take(4))
            Text(
              ch,
              style: XqTypography.headlineLarge.copyWith(
                color: theme.textPrimary,
                fontSize: 19,
                height: 1.2,
              ),
            ),
          const SizedBox(height: 10),
          XqPigmentDab(
            color: Color(moodColors[mood] ?? 0xFF7A7871),
            size: 14,
            seed: mood + i,
          ),
          const SizedBox(height: 6),
          Text(
            '$count 笔',
            style: TextStyle(
              color: theme.textTertiary,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(ThemeState theme) {
    final line = UnderlineInputBorder(
      borderSide: BorderSide(color: theme.frameColor, width: 0.8),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        style: TextStyle(color: theme.textPrimary, fontSize: 15),
        cursorColor: theme.accentColor,
        decoration: InputDecoration(
          hintText: '找一座城',
          isDense: true,
          filled: false,
          border: line,
          enabledBorder: line,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: theme.textPrimary, width: 1),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 10, 12),
            child: XqIcon(XqIcons.search, size: 18, color: theme.textTertiary),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 28),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  tooltip: '清空',
                  icon: XqIcon(
                    XqIcons.close,
                    size: 16,
                    color: theme.textTertiary,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // ── Sort Sheet ──

  void _showSortSheet(ThemeState theme) {
    final options = [('hot', '足迹最多'), ('near', '离我最近'), ('alpha', '按名称')];
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
                style: XqTypography.headlineSmall.copyWith(
                  color: theme.textPrimary,
                ),
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
                      ? XqIcon(
                          XqIcons.check,
                          size: 18,
                          color: theme.accentColor,
                        )
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

  // ── 地名笺：城名刻成白文朱印 + 这座城的气质（楷）+ 写足迹 ──

  Widget _statsHeader(MapState map, ThemeState theme) {
    final myCity = map.myCity;
    final totalActive = MapState.allCityList
        .where((c) => map.cityCommentCount(c.code) > 0)
        .length;
    final intro = myCity == null ? null : CityIntroData.get(myCity.code);
    final mine = myCity == null ? 0 : map.cityCommentCount(myCity.code);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: XqSurface(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (myCity != null)
                  XqSeal(
                    char: myCity.name,
                    color: theme.sealColor,
                    size: 58,
                    style: XqSealStyle.bai,
                    angle: -0.04,
                  )
                else
                  XqSeal(
                    char: '城',
                    color: theme.textTertiary,
                    size: 58,
                    angle: -0.04,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        myCity != null ? '你在${myCity.name}' : '还不知道你在哪',
                        style: XqTypography.headlineLarge.copyWith(
                          color: theme.textPrimary,
                          fontSize: 21,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        intro?.vibe ??
                            (myCity == null
                                ? '打开定位后，这里会显示你所在的城。'
                                : myCity.province),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: XqTypography.content,
                          fontFamilyFallback: XqTypography.contentFallback,
                          color: theme.textSecondary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 0.6, color: theme.borderColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (myCity != null) mine > 0 ? '这里有 $mine 条足迹' : '这里还没人写',
                      '共 $totalActive 座城有人写过',
                    ].join(' · '),
                    style: TextStyle(color: theme.textTertiary, fontSize: 12.5),
                  ),
                ),
                if (myCity != null)
                  FilledButton(
                    onPressed: () {
                      map.selectCityCode(myCity.code);
                      CityCommentSheet.show(context);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(84, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('写足迹'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 城市行：宋体城名 + 省份距离 + 一句气质；右侧足迹数与釉色点 ──

  Widget _cityRow(
    CityData city,
    MapState map,
    ThemeState theme, {
    required bool last,
  }) {
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
        : (intro?.vibe ?? '还没人写');

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
                : Border(
                    bottom: BorderSide(color: theme.borderColor, width: 0.6),
                  ),
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
                            fontSize: 20,
                            letterSpacing: 1,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          XqSeal(
                            char: '在',
                            color: theme.sealColor,
                            size: 18,
                            style: XqSealStyle.bai,
                            angle: 0.05,
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
                        fontFamily: XqTypography.content,
                        fontFamilyFallback: XqTypography.contentFallback,
                        color: hasActivity
                            ? theme.textSecondary
                            : theme.textTertiary,
                        fontSize: 15,
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
                          XqPigmentDab(
                            color: _moodColor(mood),
                            size: 13,
                            seed: count,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 15,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : XqIcon(
                        XqIcons.chevronRight,
                        size: 16,
                        color: theme.frameColor,
                      ),
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
    final quote = '共收 $total 座城';

    final quietCities = MapState.allCityList
        .where((c) => map.cityCommentCount(c.code) == 0)
        .toList();
    final showEgg =
        quietCities.isNotEmpty &&
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
                '随手翻一座：${eggCity.name}',
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
            style: TextStyle(color: theme.textTertiary, fontSize: 12),
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

  /// 没有城市简介时的一句：只说数据里有的事
  String _moodLine(String? mood, String name, int count) {
    final label = switch (mood) {
      'warm' => '温暖',
      'sad' => '忧伤',
      'anxious' => '焦虑',
      'calm' => '平静',
      'excited' => '兴奋',
      _ => null,
    };
    if (count == 0) return '还没人写';
    return label == null ? '$count 条足迹' : '$count 条足迹，多是$label';
  }
}
