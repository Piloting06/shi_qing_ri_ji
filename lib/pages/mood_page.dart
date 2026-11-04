import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/xq_typography.dart';
import '../theme/xq_paper_textures.dart';
import '../theme/xq_decorations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../api/api_client.dart';
import '../constants/mood.dart';
import '../pages/story_page.dart';
import '../widgets/mood_card/mood_card_data.dart';
import '../widgets/pressable_scale.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../widgets/mood_card_maker.dart';
import '../widgets/xq_toast.dart';
import '../services/mood_queue.dart';
import 'treehole_page.dart';

class MoodPage extends StatefulWidget {
  const MoodPage({super.key});
  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage>
    with SingleTickerProviderStateMixin {
  int _moodScore = 0;
  final _notesCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _editorKey = GlobalKey();
  final _emotionsKey = GlobalKey();
  final Map<int, String> _emotionNotes = {};
  List<String> _selectedTags = [];
  bool _saving = false;
  bool _saved = false;
  bool _dirty = false;
  bool _hydrating = false;
  bool _dateAutoCorrected = false;
  List<Map<String, dynamic>> _allMoods = [];
  List<Map<String, dynamic>> _dayMoods = [];
  bool _dayMoodsExpanded = false;

  // Breathing animation for empty state
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _notesCtrl.addListener(_markDirty);
    _loadDate(context.read<AppState>().selectedDate);
    _loadAllMoods();
    _flushQueue();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadAllMoods() async {
    try {
      final data = await Api.getAllMoods();
      if (mounted && data['moods'] != null) {
        setState(
          () => _allMoods = List<Map<String, dynamic>>.from(data['moods']),
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) XqToast.error(context, '加载心情统计失败：${e.message}');
    } catch (_) {
      if (mounted) XqToast.error(context, '没连上网络，稍后再试');
    }
  }

  @override
  void dispose() {
    _notesCtrl.removeListener(_markDirty);
    _notesCtrl.dispose();
    _scrollCtrl.dispose();
    _breathCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_hydrating || _dirty) return;
    setState(() {
      _dirty = true;
      _saved = false;
    });
  }

  Future<void> _loadDate(String date, {bool showSnack = false}) async {
    _hydrating = true;
    if (mounted) {
      setState(() {
        _moodScore = 0;
        _notesCtrl.clear();
        _emotionNotes.clear();
        _selectedTags = [];
        _dirty = false;
        _saved = false;
        _dayMoods = [];
      });
    }

    try {
      final moods = await Api.getMoodsByDate(date);
      if (!mounted) return;

      setState(() {
        _dayMoods = moods;
        if (moods.isNotEmpty) {
          final latest = moods.last;
          _moodScore = _readMoodScore(latest['emotion_type']);
          _notesCtrl.text = latest['notes'] ?? '';
          if (_moodScore > 0) _emotionNotes[_moodScore] = _notesCtrl.text;
          _selectedTags =
              (latest['emotion_tags'] as String?)
                  ?.split(',')
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              [];
        }
        _dirty = false;
        _saved = false;
      });
      _hydrating = false;

      if (showSnack && mounted) {
        final msg = moods.isEmpty ? '该日期暂无记录' : '已加载 $date 的 ${moods.length} 条记录';
        XqToast.info(context, msg);
      }
    } on ApiException catch (e) {
      _hydrating = false;
      if (e.statusCode == 401) return;
      if (mounted) XqToast.error(context, '加载心情失败：${e.message}');
    } catch (_) {
      _hydrating = false;
      if (mounted) XqToast.error(context, '加载心情失败，请稍后重试');
    }
  }

  void _changeDate(String date, {bool showSnack = false}) {
    context.read<AppState>().setSelectedDate(date);
    _loadDate(date, showSnack: showSnack);
  }

  int _readMoodScore(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _scrollToEditor() {
    if (_editorKey.currentContext == null) return;
    Scrollable.ensureVisible(
      _editorKey.currentContext!,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );
  }

  void _scrollToEmotions() {
    if (_emotionsKey.currentContext == null) return;
    Scrollable.ensureVisible(
      _emotionsKey.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  void _selectMood(int s) {
    setState(() {
      if (s != _moodScore) {
        _emotionNotes[_moodScore] = _notesCtrl.text;
        _moodScore = s;
        _notesCtrl.text = _emotionNotes[s] ?? '';
      } else {
        _emotionNotes[_moodScore] = _notesCtrl.text;
        _moodScore = 0;
      }
      _dirty = true;
      _saved = false;
    });
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt.toString());
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, String>> get _currentTags => emotionTags[_moodScore] ?? [];

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final date = context.read<AppState>().selectedDate;
    try {
      // 附带定位城市与当天天气码（城迹榜 + 心晴签历史洞察的数据源）
      final prefs = await SharedPreferences.getInstance();
      final fullCity = prefs.getString('weather_city') ?? '';
      final city = fullCity.split('，').first;
      int? weatherCode;
      try {
        final wdata = jsonDecode(prefs.getString('weather_data') ?? '{}');
        weatherCode =
            ((wdata['current'] as Map?)?['weather_code'] as num?)?.toInt();
      } catch (_) {}
      await Api.saveMood(date, _moodScore, _notesCtrl.text, _selectedTags, [],
          city: city, weatherCode: weatherCode);

      await _loadAllMoods();
      final dayMoods = await Api.getMoodsByDate(date);

      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
          _dirty = false;
          _dayMoods = dayMoods;
        });
        final prefs = await SharedPreferences.getInstance();
        final hasSaved = prefs.getBool('mood_has_saved') ?? false;
        if (!hasSaved) {
          await prefs.setBool('mood_has_saved', true);
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) XqToast.info(context, '试试把心情制成卡片分享给朋友吧 →');
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        XqToast.error(context, '保存失败：${e.message}');
      }
    } catch (_) {
      await MoodQueue.enqueue({
        'date': date,
        'emotion_type': _moodScore,
        'emotion_tags': _selectedTags.join(','),
        'notes': _notesCtrl.text,
      });
      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
          _dirty = false;
        });
        XqToast.info(context, '已暂存，联网后自动同步');
      }
    }
  }

  Future<void> _flushQueue() async {
    final sent = await MoodQueue.flush();
    if (sent > 0 && mounted) {
      XqToast.success(context, '已同步 $sent 条离线记录');
      _loadAllMoods();
    }
  }

  Future<void> _openCardMaker() async {
    final appState = context.read<AppState>();
    String? weatherText, cityName, temperature;
    try {
      final prefs = await SharedPreferences.getInstance();
      final weatherData = prefs.getString('weather_data');
      if (weatherData != null) {
        final d = const JsonDecoder().convert(weatherData);
        final current = d['current'] as Map<String, dynamic>?;
        if (current != null) {
          weatherText = current['weather']?.toString();
          temperature = current['temp_current']?.toString() != null
              ? '${current['temp_current']}°'
              : null;
        }
      }
      cityName = prefs.getString('weather_city')?.toString();
      if (cityName != null && cityName.contains('，')) {
        cityName = cityName.split('，').first;
      }
    } catch (_) {}
    if (!mounted) return;
    await MoodCardMaker.show(
      context,
      date: appState.selectedDate,
      moodLabel: moodLabels[_moodScore] ?? '心情',
      moodScore: _moodScore,
      text: _notesCtrl.text,
      tags: _selectedTags,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      weatherText: weatherText,
      cityName: cityName,
      temperature: temperature,
    );
    if (mounted) setState(() => _saved = false);
  }

  // ── Quick Stats Computation ──

  ({int streak, int monthCount, int topScore}) _computeStats() {
    if (_allMoods.isEmpty) return (streak: 0, monthCount: 0, topScore: 0);

    // Group by date
    final byDate = <String, int>{};
    for (final m in _allMoods) {
      final d = m['date']?.toString() ?? '';
      if (d.isEmpty) continue;
      final s = _readMoodScore(m['emotion_type']);
      if (s > 0 && (!byDate.containsKey(d) || true)) {
        byDate[d] = s; // keep last score per date
      }
    }

    // Streak: consecutive days ending today
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      final key = _fmtDate(d);
      if (byDate.containsKey(key)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    // Month count
    final monthStart = DateTime(today.year, today.month, 1);
    final monthCount = _allMoods.where((m) {
      final d = DateTime.tryParse(m['date']?.toString() ?? '');
      return d != null && !d.isBefore(monthStart) && !d.isAfter(today);
    }).length;

    // Top mood
    final freq = <int, int>{};
    for (final m in _allMoods.take(30)) {
      final s = _readMoodScore(m['emotion_type']);
      if (s > 0) freq[s] = (freq[s] ?? 0) + 1;
    }
    int topScore = 0;
    if (freq.isNotEmpty) {
      topScore = freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    return (streak: streak, monthCount: monthCount, topScore: topScore);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final appState = context.watch<AppState>();
    final t = theme;

    if (!_dateAutoCorrected) {
      _dateAutoCorrected = true;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (appState.selectedDate != today) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<AppState>().setSelectedDate(today);
            _loadDate(today);
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: t.backgroundColor,
      // 保存条吸底：Scaffold 自动避让键盘
      bottomNavigationBar: _buildInlineSaveBar(t),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await _loadAllMoods();
                if (!context.mounted) return;
                final date = context.read<AppState>().selectedDate;
                final dayMoods = await Api.getMoodsByDate(date);
                if (mounted) setState(() => _dayMoods = dayMoods);
              },
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Header
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今天的心情',
                            style: XqTypography.headlineLarge.copyWith(
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: t.accentColor),
                        onPressed: () {
                          final d = DateTime.parse(
                            appState.selectedDate,
                          ).subtract(const Duration(days: 1));
                          _changeDate(DateFormat('yyyy-MM-dd').format(d));
                        },
                      ),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(appState.selectedDate) ??
                                DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) {
                            _changeDate(DateFormat('yyyy-MM-dd').format(d));
                          }
                        },
                        child: Text(
                          appState.selectedDate,
                          style: TextStyle(
                            color: t.textPrimary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: t.accentColor),
                        onPressed: () {
                          final d = DateTime.parse(
                            appState.selectedDate,
                          ).add(const Duration(days: 1));
                          if (!d.isAfter(DateTime.now())) {
                            _changeDate(DateFormat('yyyy-MM-dd').format(d));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4-column emotion pills
                  GridView.count(
                    key: _emotionsKey,
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.0,
                    children: List.generate(8, (i) {
                      final s = i + 1;
                      final active = s == _moodScore;
                      final color = Color(moodColors[s]!);
                      return PressableScale(
                        onTap: () => _selectMood(s),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: active
                                ? color.withAlpha(24)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? color.withAlpha(170)
                                  : t.borderColor.withAlpha(80),
                              width: active ? 1.2 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${moodEmojis[s]} ${moodLabels[s]}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight:
                                      active ? FontWeight.w600 : FontWeight.w400,
                                  color: active ? color : t.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Emotion tags
                  if (_moodScore > 0 && _currentTags.isNotEmpty) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _currentTags.take(8).toList().asMap().entries.map(
                        (entry) {
                          final tag = entry.value;
                          final sel = _selectedTags.contains(tag['id']);
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (sel) {
                                _selectedTags.remove(tag['id']);
                              } else {
                                _selectedTags.add(tag['id']!);
                              }
                              _dirty = true;
                              _saved = false;
                            }),
                            child: Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel
                                    ? t.accentColor.withAlpha(24)
                                    : t.sunkenColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                '${tag['icon']} ${tag['label']}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight:
                                      sel ? FontWeight.w600 : FontWeight.w400,
                                  color: sel ? t.accentColor : t.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes — lined paper style
                  AnimatedContainer(
                    key: _editorKey,
                    duration: const Duration(milliseconds: 180),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: t.cardColor,
                      borderRadius: BorderRadius.circular(
                        XqDecorations.radiusMedium,
                      ),
                      border: Border.all(
                        color: t.borderColor,
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LinedPaperPainter(
                              lineColor: t.paperLine,
                              lineSpacing: 28,
                              marginLeft: 48,
                            ),
                          ),
                        ),
                        TextField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            style: XqTypography.handwrittenBody.copyWith(
                              color: t.textPrimary,
                            ),
                            cursorColor: t.accentColor,
                            cursorWidth: 2.0,
                            onTap: () => Future.delayed(
                              const Duration(milliseconds: 300),
                              _scrollToEditor,
                            ),
                            decoration: InputDecoration(
                              hintText: _moodScore == 0
                                  ? '写点什么吧...'
                                  : _placeholderForScore(_moodScore),
                              hintStyle: TextStyle(
                                color: t.textSecondary.withAlpha(100),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(14),
                            ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 100), // 为吸底保存条留出缓冲

                  // ── 回顾区 ──
                  Text(
                    '最近的轨迹',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 7-day mood streak strip
                  _buildMoodStreak(t, appState),
                  const SizedBox(height: 12),

                  // Quick stats row
                  _buildQuickStats(t),
                  const SizedBox(height: 10),
                  _buildWeekSummary(t),
                  const SizedBox(height: 12),

                  // Day mood summary / empty state
                  _buildDayCard(t),
                  const SizedBox(height: 16),

                  // 素笺 · 树洞
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StoryListPage(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.spa_outlined,
                            size: 16,
                            color: t.textTertiary,
                          ),
                          label: Text(
                            '写素笺',
                            style: TextStyle(
                              color: t.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TreeholePage(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.auto_awesome_outlined,
                            size: 16,
                            color: t.textTertiary,
                          ),
                          label: Text(
                            '去树洞说说',
                            style: TextStyle(
                              color: t.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 7-Day Mood Streak Strip ──

  Widget _buildMoodStreak(ThemeState t, AppState appState) {
    final today = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    // Build 7-day data
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final key = _fmtDate(d);
      final isToday = i == 6;
      // Get latest mood for that date
      int? score;
      for (final m in _allMoods) {
        if (m['date'] == key) {
          score = _readMoodScore(m['emotion_type']);
          break;
        }
      }
      return (date: key, day: d, weekday: weekdays[d.weekday - 1], score: score, isToday: isToday);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近 7 天',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((d) {
            final hasData = d.score != null && d.score! > 0;
            final isSelected = d.date == appState.selectedDate;
            final moodColor = hasData
                ? Color(moodColors[d.score!] ?? 0xFF90A4AE)
                : Colors.transparent;

            return GestureDetector(
              onTap: () => _changeDate(d.date),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hasData ? moodColor.withAlpha(30) : t.surfaceAlpha,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? t.accentColor
                            : hasData
                                ? moodColor.withAlpha(80)
                                : t.borderColor.withAlpha(60),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: hasData
                          ? Text(
                              moodEmojis[d.score!] ?? '',
                              style: const TextStyle(fontSize: 14),
                            )
                          : Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: t.borderColor.withAlpha(80),
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.weekday,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? t.accentColor
                          : t.textTertiary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Quick Stats Row ──

  Widget _buildQuickStats(ThemeState t) {
    final stats = _computeStats();
    if (stats.streak == 0 && stats.monthCount == 0 && stats.topScore == 0) {
      return const SizedBox.shrink();
    }

    final pills = <Widget>[];

    if (stats.streak > 0) {
      pills.add(_statPill(t, '🔥', '连续${stats.streak}天'));
    }
    if (stats.monthCount > 0) {
      pills.add(_statPill(t, '📝', '本月${stats.monthCount}条'));
    }
    if (stats.topScore > 0) {
      pills.add(_statPill(
        t,
        moodEmojis[stats.topScore] ?? '✨',
        '最常${moodLabels[stats.topScore] ?? ''}',
      ));
    }

    if (pills.isEmpty) return const SizedBox.shrink();

    return Row(
      children: pills.map((p) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: p,
      )).toList(),
    );
  }

  Widget _statPill(ThemeState t, String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.accentColor.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.accentColor.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Day Card (Timeline / Empty State) ──

  /// 回顾区：本周小结（记录天数 + 最常出现的心情）
  Widget _buildWeekSummary(ThemeState t) {
    final stats = computeMoodStats(_allMoods, DateTime.now());
    final week = stats.week;
    final recorded = week
        .where((d) => d.emoji != null && d.emoji!.isNotEmpty)
        .length;
    if (recorded == 0) return const SizedBox.shrink();

    final counts = <String, int>{};
    final colors = <String, int?>{};
    for (final d in week) {
      if (d.emoji == null || d.emoji!.isEmpty) continue;
      counts[d.emoji!] = (counts[d.emoji!] ?? 0) + 1;
      colors[d.emoji!] = d.color;
    }
    String topEmoji = '';
    var topCount = 0;
    counts.forEach((emoji, n) {
      if (n > topCount) {
        topCount = n;
        topEmoji = emoji;
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: t.borderColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, size: 17, color: t.accentColor),
          const SizedBox(width: 8),
          Text(
            '本周记录 $recorded/7 天',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (topEmoji.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 12,
              color: t.borderColor,
            ),
            const SizedBox(width: 10),
            Text(
              '最常出现 $topEmoji ×$topCount',
              style: TextStyle(
                color: Color(colors[topEmoji] ?? 0xFF8A7350),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCard(ThemeState t) {
    if (_dayMoods.isEmpty) return _buildEmptyCard(t);
    return _buildDayTimeline(t);
  }

  Widget _buildEmptyCard(ThemeState t) {
    final appState = context.read<AppState>();
    return GestureDetector(
      onTap: _scrollToEmotions,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
          border: Border.all(color: t.borderColor.withAlpha(80)),
          boxShadow: XqDecorations.shadowSubtle(dark: t.isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: LinedPaperPainter(
                    lineColor: t.paperLine.withAlpha(40),
                    lineSpacing: 28,
                    marginLeft: 48,
                  ),
                ),
              ),
              // Breathing emoji animation
              Center(
                child: FadeTransition(
                  opacity: _breathAnim,
                  child: Text(
                    '😊',
                    style: TextStyle(
                      fontSize: 40,
                      color: t.accentColor.withAlpha(40),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.selectedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: t.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '今天还没有心情记录',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '选一个心情，开始记录吧',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          'SHI QING',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: t.accentColor.withAlpha(60),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Day Timeline ──

  Widget _buildDayTimeline(ThemeState t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusMedium),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _dayMoodsExpanded = !_dayMoodsExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(Icons.today_outlined, size: 16, color: t.accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '今天已记 ${_dayMoods.length} 条',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _dayMoodsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: t.textTertiary,
                ),
              ],
            ),
          ),

          // Compact timeline (always visible)
          if (!_dayMoodsExpanded) ...[
            const SizedBox(height: 10),
            _buildCompactTimeline(t),
          ],

          // Expanded detail list
          if (_dayMoodsExpanded) ...[
            const SizedBox(height: 8),
            ..._dayMoods.map((m) => _buildTimelineDetailItem(m, t)),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTimeline(ThemeState t) {
    if (_dayMoods.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Connection line
                Positioned(
                  top: 20,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: t.borderColor.withAlpha(80),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // Mood nodes
                ..._dayMoods.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  final score = _readMoodScore(m['emotion_type']);
                  final color = Color(moodColors[score] ?? 0xFF90A4AE);
                  final fraction = _dayMoods.length == 1
                      ? 0.5
                      : i / (_dayMoods.length - 1);

                  return Positioned(
                    left: fraction * (MediaQuery.of(context).size.width - 96 - 32),
                    top: 6,
                    child: GestureDetector(
                      onTap: () => _showMoodDetail(m),
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.withAlpha(100),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                moodEmojis[score] ?? '',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time indicators
          if (_dayMoods.length <= 4)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(_dayMoods.first['created_at']),
                  style: TextStyle(fontSize: 9, color: t.textTertiary),
                ),
                if (_dayMoods.length > 1)
                  Text(
                    _formatTime(_dayMoods.last['created_at']),
                    style: TextStyle(fontSize: 9, color: t.textTertiary),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineDetailItem(Map<String, dynamic> m, ThemeState t) {
    final score = _readMoodScore(m['emotion_type']);
    final color = Color(moodColors[score] ?? 0xFF90A4AE);
    final notes = m['notes']?.toString() ?? '';
    final tags = (m['emotion_tags'] as String?)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time + emoji node
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(100), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    moodEmojis[score] ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${moodLabels[score] ?? ''}  ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      _formatTime(m['created_at']),
                      style: TextStyle(fontSize: 11, color: t.textTertiary),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textSecondary, height: 1.4),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tag, style: TextStyle(fontSize: 10, color: color)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteDayMood(m['id'] as int),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.close, size: 16, color: t.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoodDetail(Map<String, dynamic> m) {
    final t = context.read<ThemeState>();
    final score = _readMoodScore(m['emotion_type']);
    final notes = m['notes']?.toString() ?? '';
    final tags = (m['emotion_tags'] as String?)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    showModalBottomSheet(
      context: context,
      backgroundColor: t.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(moodEmojis[score] ?? '', style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(
                    moodLabels[score] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(m['created_at']),
                    style: TextStyle(fontSize: 13, color: t.textTertiary),
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(notes, style: TextStyle(fontSize: 14, color: t.textSecondary, height: 1.5)),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.accentColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(tag, style: TextStyle(fontSize: 12, color: t.accentColor)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDayMood(int id) async {
    final date = context.read<AppState>().selectedDate;
    setState(() => _dayMoods.removeWhere((m) => m['id'] == id));

    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    final accentColor = context.read<ThemeState>().accentColor;
    final undoController = messenger.showSnackBar(
      SnackBar(
        content: const Text('已删除心情记录'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '撤销',
          textColor: accentColor,
          onPressed: () => undone = true,
        ),
      ),
    );

    await undoController.closed;

    if (undone) {
      await _loadAllMoods();
      final dayMoods = await Api.getMoodsByDate(date);
      if (mounted) setState(() => _dayMoods = dayMoods);
      return;
    }

    try {
      await Api.deleteMood(id);
      await _loadAllMoods();
    } catch (_) {}
  }

  // ── Save Bar ──

  Widget _buildInlineSaveBar(ThemeState t) {
    final status = _saving
        ? '保存中...'
        : _saved
        ? '已保存'
        : _dirty
        ? '有改动未保存'
        : '选择心情或写下文字';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.cardColor.withAlpha(245),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.borderColor),
        boxShadow: XqDecorations.shadowSubtle(dark: t.isDark),
      ),
      child: Row(
        children: [
          Icon(
            _saved ? Icons.check_circle_outline : Icons.edit_note_outlined,
            color: _saved ? t.successColor : t.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (_saved) ...[
            TextButton.icon(
              onPressed: _openCardMaker,
              icon: Icon(Icons.auto_awesome, size: 16, color: t.gold),
              label: Text(
                '制作卡片',
                style: TextStyle(
                  color: t.gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: (_dirty && !_saving) ? _save : null,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.textOnAccent,
                      ),
                    )
                  : Icon(_saved ? Icons.check : Icons.save_outlined, size: 18),
              label: Text(_saving ? '保存中' : '保存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accentColor,
                foregroundColor: t.textOnAccent,
                disabledBackgroundColor: t.borderColor,
                disabledForegroundColor: t.textTertiary,
                elevation: 0,
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Placeholder Text ──

  String _placeholderForScore(int score) {
    switch (score) {
      case 1:
        return '开心的事，记下来';
      case 2:
        return '这样的平静也很珍贵...';
      case 3:
        return '没关系的，把它写下来吧...';
      case 4:
        return '写出来可能会好受一点...';
      case 5:
        return '别担心，我们一起面对...';
      case 6:
        return '累了就休息，不需要理由～';
      case 7:
        return '在期待什么呢？分享一下吧～';
      case 8:
        return '想TA了就说出来吧...';
      default:
        return '今天发生了什么...';
    }
  }
}
