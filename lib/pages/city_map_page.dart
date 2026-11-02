import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../constants/mood.dart';
import '../stores/map_state.dart';
import '../stores/theme_state.dart';
import '../widgets/city_comment_sheet.dart';
import '../widgets/glow_wrap.dart';
import '../widgets/xq_toast.dart';
import '../theme/xq_decorations.dart';
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
    ('warm', '🌤 温暖', 'warm'),
    ('sad', '🌧 忧伤', 'sad'),
    ('calm', '🍃 平静', 'calm'),
    ('anxious', '⚡ 焦虑', 'anxious'),
    ('excited', '🎉 兴奋', 'excited'),
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
              Icon(Icons.public, size: 48, color: theme.accentColor.withAlpha(80)),
              const SizedBox(height: 16),
              Text(
                '正在加载城市情绪…',
                style: TextStyle(color: theme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                '首次加载可能需要几秒',
                style: TextStyle(color: theme.textTertiary, fontSize: 12),
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

    final activeCities =
        filtered.where((c) => map.cityCommentCount(c.code) > 0).toList();
    final quietCities =
        filtered.where((c) => map.cityCommentCount(c.code) == 0).toList();

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
              // Search bar + sort button
              SliverToBoxAdapter(child: _searchBar(theme)),

              // Mood filter chips
              SliverToBoxAdapter(child: _filterChips(map, theme)),

              // Stats header
              if (_search.trim().isEmpty && _moodFilter == 'all')
                SliverToBoxAdapter(child: _statsHeader(map, theme)),

              // 城市心晴榜（最近7天）
              if (_search.trim().isEmpty && _moodFilter == 'all')
                SliverToBoxAdapter(child: _moodboardSection(theme)),

              // Active cities section
              if (activeCities.isNotEmpty &&
                  (_search.trim().isEmpty || _moodFilter == 'all' || _moodFilter != 'all')) ...[
                if (_search.trim().isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 15, color: theme.accentColor),
                          const SizedBox(width: 6),
                          Text(
                            '正在说话的城市',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${activeCities.length}',
                            style: TextStyle(
                              color: theme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _cityCard(activeCities[i], map, theme),
                      childCount: activeCities.length,
                    ),
                  ),
                ),

                // Quiet section — only show when not filtering by mood
                if (quietCities.isNotEmpty && _moodFilter == 'all') ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.explore_outlined,
                              size: 15, color: theme.textTertiary),
                          const SizedBox(width: 6),
                          Text(
                            '等待第一个说话的人',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${quietCities.length}',
                            style: TextStyle(
                              color: theme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _cityCard(quietCities[i], map, theme),
                        childCount: quietCities.length,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Empty state
                filtered.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptySearch(theme),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _cityCard(filtered[i], map, theme),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
              ],

              // Footer
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildFooter(map, theme),
                ),
              ),
            ],
          ),
        ),
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

  // ── Filter Chips ──

  Widget _filterChips(MapState map, ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterOptions.map((opt) {
            final (key, label, _) = opt;
            final active = _moodFilter == key;
            final chipColor =
                key != 'all' ? _moodColor(key) : theme.accentColor;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GlowWrap(
                accentColor: active ? chipColor : theme.accentColor,
                radius: 20,
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _moodFilter = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? chipColor.withAlpha(28)
                        : theme.surfaceAlpha,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? chipColor.withAlpha(180)
                          : theme.borderColor.withAlpha(80),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? chipColor : theme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Search Bar ──

  Widget _moodboardSection(ThemeState theme) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _moodboard,
      builder: (context, snap) {
        final board =
            (snap.data?['board'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (board.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.leaderboard_rounded,
                        size: 15, color: theme.gold),
                    const SizedBox(width: 6),
                    Text(
                      '城市心晴榜',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '最近7天',
                      style: TextStyle(
                        color: theme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: board.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final item = board[i];
                    final fullName = item['city']?.toString() ?? '';
                    final city = fullName.split('，').first;
                    final mood = (item['top_mood'] as num?)?.toInt() ?? 0;
                    final count = (item['count'] as num?)?.toInt() ?? 0;
                    final color = Color(moodColors[mood] ?? 0xFF90A4AE);
                    return Container(
                      width: 92,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: theme.borderColor.withAlpha(80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  color: i < 3
                                      ? theme.gold
                                      : theme.textTertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                moodEmojis[mood] ?? '',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$count 条 · ${moodLabels[mood] ?? ''}',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchBar(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor.withAlpha(180),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.borderColor.withAlpha(120)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  cursorColor: theme.accentColor,
                  decoration: InputDecoration(
                    hintText: '搜城市…',
                    hintStyle:
                        TextStyle(color: theme.textTertiary, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search, color: theme.textSecondary, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: theme.textSecondary, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: theme.cardColor.withAlpha(180),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showSortSheet(theme),
                child: Icon(Icons.sort_rounded,
                    color: theme.textSecondary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sort Sheet ──

  void _showSortSheet(ThemeState theme) {
    final options = [
      ('hot', '最热', Icons.local_fire_department_outlined),
      ('near', '离我最近', Icons.near_me_outlined),
      ('alpha', 'A-Z', Icons.sort_by_alpha_outlined),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '排序方式',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                ),
              ),
            ),
            ...options.map((opt) {
              final (key, label, icon) = opt;
              final active = _sortBy == key;
              return ListTile(
                leading: Icon(icon,
                    size: 20,
                    color: active ? theme.accentColor : theme.textSecondary),
                title: Text(
                  label,
                  style: TextStyle(
                    color: active ? theme.accentColor : theme.textPrimary,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: active
                    ? Icon(Icons.check, size: 20, color: theme.accentColor)
                    : null,
                onTap: () {
                  setState(() => _sortBy = key);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Stats Header ──

  Widget _statsHeader(MapState map, ThemeState theme) {
    final myCity = map.myCity;
    final totalActive = MapState.allCityList
        .where((c) => map.cityCommentCount(c.code) > 0)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: myCity != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.accentColor.withAlpha(18),
                    theme.accentColor.withAlpha(6),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.accentColor.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.accentColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.location_on,
                        color: theme.accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '你在 ${myCity.name}',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalActive 座城市正在分享情绪',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      map.selectCityCode(myCity.code);
                      CityCommentSheet.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '写足迹',
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor.withAlpha(120),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.explore, size: 22, color: theme.textTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalActive 座城市有人在说话',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '定位或搜索你的城市，留下足迹',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── City Card ──

  Widget _cityCard(CityData city, MapState map, ThemeState theme) {
    final isMe = map.myCity != null && map.myCity!.code == city.code;
    final count = map.cityCommentCount(city.code);
    final mood = map.cityMood(city.code);
    final hasActivity = count > 0;
    final dist = map.distanceTo(city);
    final intro = CityIntroData.get(city.code);

    // Format distance string
    String? distStr;
    if (dist != null) {
      if (dist < 1) {
        distStr = '<1km';
      } else if (dist >= 1000) {
        distStr = '${(dist / 1000).toStringAsFixed(0)}k km';
      } else {
        distStr = '${dist.toStringAsFixed(0)}km';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        onTap: () {
          HapticFeedback.selectionClick();
          map.selectCityCode(city.code);
          CityCommentSheet.show(context);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          final intro = CityIntroData.get(city.code);
          if (intro == null) return;
          XqToast.info(context, '${city.name} · ${intro.vibe}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasActivity
                ? _moodBg(mood, theme).withAlpha(theme.isDark ? 55 : 40)
                : theme.cardColor.withAlpha(120),
            borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
            border: Border.all(
              color: isMe
                  ? const Color(0xFFFF9F1C)
                  : hasActivity
                      ? _moodColor(mood).withAlpha(80)
                      : theme.borderColor.withAlpha(60),
              width: isMe ? 2 : 0.5,
            ),
            boxShadow: isMe
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF9F1C).withAlpha(30),
                      blurRadius: 12,
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // City name row
              Row(
                children: [
                  if (isMe) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F1C).withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '当前',
                        style: TextStyle(
                          color: Color(0xFFFF9F1C),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      city.name,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasActivity) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _moodColor(mood).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: _moodColor(mood),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Province + distance
              Text(
                distStr != null
                    ? '${city.province} · 距你$distStr'
                    : city.province,
                style: TextStyle(color: theme.textTertiary, fontSize: 11),
              ),
              const SizedBox(height: 8),
              // Content area
              Expanded(
                child: hasActivity
                    ? _activeCardContent(mood, city, count, intro, theme)
                    : _quietCardContent(city, intro, theme),
              ),
              // Mood glow bar for active cities
              if (hasActivity && mood != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1.5),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _moodColor(mood).withAlpha(0),
                            _moodColor(mood).withAlpha(100),
                            _moodColor(mood).withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeCardContent(
      String? mood, CityData city, int count, CityIntro? intro, ThemeState theme) {
    // Prefer vibe over moodLine
    final displayText = intro?.vibe ?? _moodLine(mood, city.name, count);
    return Text(
      displayText,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 11,
        height: 1.5,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _quietCardContent(CityData cityData, CityIntro? intro, ThemeState theme) {
    if (intro != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intro.vibe,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: intro.tags.take(3).map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.accentColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          Text(
            '做第一个留下足迹的人',
            style: TextStyle(
              color: theme.textTertiary.withAlpha(120),
              fontSize: 10,
            ),
          ),
        ],
      );
    }
    // No intro data — keep original style
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '${cityData.name}还在等第一个说话的人',
            style: TextStyle(
              color: theme.textTertiary,
              fontSize: 11,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '还没有足迹',
            style: TextStyle(
              color: theme.textTertiary.withAlpha(100),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty Search ──

  Widget _emptySearch(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: theme.textTertiary),
          const SizedBox(height: 12),
          Text(
            '没找到这个城市',
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
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.cardColor.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.borderColor.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore, size: 14, color: theme.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    '也许你想去${eggCity.name}看看？',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
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

  Color _moodColor(String? mood) {
    return switch (mood) {
      'warm' => const Color(0xFFF0A830),
      'sad' => const Color(0xFF7B9BB8),
      'anxious' => const Color(0xFFB090C8),
      'calm' => const Color(0xFF78B090),
      'excited' => const Color(0xFFF08848),
      _ => const Color(0xFF8899AA),
    };
  }

  Color _moodBg(String? mood, ThemeState theme) => _moodColor(mood);

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
