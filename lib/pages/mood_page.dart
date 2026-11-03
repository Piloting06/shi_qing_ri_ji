import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/xq_typography.dart';
import '../theme/xq_paper_textures.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../api/api_client.dart';
import '../constants/mood.dart';
import '../pages/story_page.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../widgets/mood_card_maker.dart';
import '../widgets/xq_toast.dart';
import '../utils/time_utils.dart';
import '../services/mood_queue.dart';
import 'treehole_page.dart';

class MoodPage extends StatefulWidget {
  const MoodPage({super.key});
  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> {
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

  @override
  void initState() {
    super.initState();
    _notesCtrl.addListener(_markDirty);
    _loadDate(context.read<AppState>().selectedDate);
    _loadAllMoods();
    _flushQueue();
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
        context.read<AppState>().bumpMoodRevision();
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

  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

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
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadAllMoods();
            if (!context.mounted) return;
            final date = context.read<AppState>().selectedDate;
            final dayMoods = await Api.getMoodsByDate(date);
            if (mounted) setState(() => _dayMoods = dayMoods);
          },
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              _buildHeader(t, appState),
              const SizedBox(height: 28),
              _sectionLabel(t, '此刻'),
              const SizedBox(height: 14),
              _buildMoodRow(t),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: (_moodScore > 0 && _currentTags.isNotEmpty)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _buildTags(t),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 24),
              _buildEditor(t),
              const SizedBox(height: 48),

              // ── 回顾区 ──
              _buildDaySection(t, appState),
              const SizedBox(height: 40),
              _buildRecentWeek(t, appState),
              const SizedBox(height: 40),
              _buildMoreLinks(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(ThemeState t, String text) => Text(
        text,
        style: TextStyle(
          color: t.textTertiary,
          fontSize: 12,
          letterSpacing: 2,
        ),
      );

  /// 页头：宋体「今天 / M月D日」+ 日期翻页（暗木数字，点日期选日子）
  Widget _buildHeader(ThemeState t, AppState appState) {
    final date = DateTime.tryParse(appState.selectedDate) ?? DateTime.now();
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);
    final canNext = !isToday && date.isBefore(now);
    final title = isToday
        ? '今天'
        : DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))
        ? '昨天'
        : '${date.month}月${date.day}日';

    Widget arrow(IconData icon, String label, VoidCallback? onTap) => Semantics(
          button: true,
          label: label,
          child: InkResponse(
            onTap: onTap,
            radius: 22,
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? t.borderColor : t.textSecondary,
              ),
            ),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: XqTypography.displayMedium.copyWith(color: t.textPrimary),
        ),
        const Spacer(),
        arrow(Icons.chevron_left, '前一天', () {
          final d = date.subtract(const Duration(days: 1));
          _changeDate(DateFormat('yyyy-MM-dd').format(d));
        }),
        Semantics(
          button: true,
          label: '选择日期',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: now,
              );
              if (d != null) _changeDate(DateFormat('yyyy-MM-dd').format(d));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${date.month.toString().padLeft(2, '0')} · ${date.day.toString().padLeft(2, '0')}  周${_weekdayNames[date.weekday - 1]}',
                style: TextStyle(
                  color: t.gold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        arrow(
          Icons.chevron_right,
          '后一天',
          canNext
              ? () {
                  final d = date.add(const Duration(days: 1));
                  _changeDate(DateFormat('yyyy-MM-dd').format(d));
                }
              : null,
        ),
      ],
    );
  }

  /// 八种心情：一行釉色墨点 + 名字。选中的墨点放大、名字着釉色、下有一笔细线。
  Widget _buildMoodRow(ThemeState t) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Row(
      key: _emotionsKey,
      children: List.generate(8, (i) {
        final s = i + 1;
        final active = s == _moodScore;
        final dimmed = _moodScore != 0 && !active;
        final color = Color(moodColors[s]!);
        return Expanded(
          child: Semantics(
            button: true,
            selected: active,
            label: moodLabels[s],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                _selectMood(s);
              },
              child: AnimatedOpacity(
                opacity: dimmed ? 0.45 : 1,
                duration: Duration(milliseconds: reduce ? 0 : 200),
                child: Column(
                  children: [
                    SizedBox(
                      height: 30,
                      child: Center(
                        child: AnimatedScale(
                          scale: active ? 1.0 : 0.62,
                          duration: Duration(milliseconds: reduce ? 0 : 200),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      moodLabels[s] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: active ? color : t.textSecondary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: Duration(milliseconds: reduce ? 0 : 200),
                      width: active ? 14 : 0,
                      height: 1.5,
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 标签：文字短签（无 emoji），选中着黛青
  Widget _buildTags(ThemeState t) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _currentTags.take(8).map((tag) {
        final sel = _selectedTags.contains(tag['id']);
        return Semantics(
          button: true,
          selected: sel,
          label: tag['label'],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (sel) {
                _selectedTags.remove(tag['id']);
              } else {
                _selectedTags.add(tag['id']!);
              }
              _dirty = true;
              _saved = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? t.accentColor.withAlpha(22) : t.sunkenColor,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: sel ? t.accentColor.withAlpha(150) : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Text(
                tag['label'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: sel ? t.accentColor : t.textSecondary,
                  fontWeight: sel ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 书写区：无框横线纸，楷体正文（内容层）
  Widget _buildEditor(ThemeState t) {
    return Container(
      key: _editorKey,
      constraints: const BoxConstraints(minHeight: 4 * 32 + 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: t.borderColor, width: 0.8),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: LinedPaperPainter(
                lineColor: t.paperLine,
                lineSpacing: 32,
                showMarginLine: false,
              ),
            ),
          ),
          TextField(
            controller: _notesCtrl,
            minLines: 4,
            maxLines: 12,
            style: XqTypography.handwrittenBody.copyWith(
              color: t.textPrimary,
              height: 32 / 17,
            ),
            cursorColor: t.accentColor,
            cursorWidth: 1.5,
            onTap: () => Future.delayed(
              const Duration(milliseconds: 300),
              _scrollToEditor,
            ),
            decoration: InputDecoration(
              hintText: _moodScore == 0
                  ? '今天发生了什么'
                  : _placeholderForScore(_moodScore),
              hintStyle: XqTypography.handwrittenBody.copyWith(
                color: t.textTertiary.withAlpha(150),
                height: 32 / 17,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
            ),
          ),
        ],
      ),
    );
  }

  /// 这一天：竖向时间线（时间 · 釉色点 · 心情 · 楷体摘句）
  Widget _buildDaySection(ThemeState t, AppState appState) {
    final date = DateTime.tryParse(appState.selectedDate) ?? DateTime.now();
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              isToday ? '今天写下的' : '这一天写下的',
              style: XqTypography.headlineSmall.copyWith(color: t.textPrimary),
            ),
            const Spacer(),
            if (_dayMoods.isNotEmpty)
              Text(
                '${_dayMoods.length} 笔',
                style: TextStyle(color: t.textTertiary, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_dayMoods.isEmpty)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _scrollToEmotions,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isToday ? '还空着。选一个此刻的心情，写下第一笔。' : '这一天没有留下记录。',
                style: TextStyle(color: t.textTertiary, fontSize: 14),
              ),
            ),
          )
        else
          for (var i = 0; i < _dayMoods.length; i++)
            _buildTimelineItem(_dayMoods[i], t, last: i == _dayMoods.length - 1),
      ],
    );
  }

  Widget _buildTimelineItem(
    Map<String, dynamic> m,
    ThemeState t, {
    required bool last,
  }) {
    final score = _readMoodScore(m['emotion_type']);
    final color = Color(moodColors[score] ?? 0xFF7C918C);
    final notes = (m['notes']?.toString() ?? '').trim();
    return Semantics(
      button: true,
      label: '${moodLabels[score] ?? ''} ${TimeUtils.hm(m['created_at'])}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showMoodDetail(m),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 44,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    TimeUtils.hm(m['created_at']),
                    style: TextStyle(
                      color: t.gold,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              // 时间线：釉色点 + 下行细线
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 0.8,
                          margin: const EdgeInsets.only(top: 4),
                          color: t.borderColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moodLabels[score] ?? '',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: XqTypography.content,
                            color: t.textSecondary,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 最近七天：七枚釉色点 + 星期；下附一行克制的统计
  Widget _buildRecentWeek(ThemeState t, AppState appState) {
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final key = _fmtDate(d);
      int? score;
      for (final m in _allMoods) {
        if (m['date'] == key) {
          score = _readMoodScore(m['emotion_type']);
          break;
        }
      }
      return (date: key, day: d, score: score);
    });
    final recorded = days.where((d) => (d.score ?? 0) > 0).length;
    final stats = _computeStats();
    final facts = [
      '本周 $recorded/7 天',
      if (stats.streak > 0) '连续 ${stats.streak} 天',
      if (stats.monthCount > 0) '本月 ${stats.monthCount} 笔',
      if (stats.topScore > 0) '最常「${moodLabels[stats.topScore] ?? ''}」',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近七天',
          style: XqTypography.headlineSmall.copyWith(color: t.textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          children: days.map((d) {
            final has = (d.score ?? 0) > 0;
            final selected = d.date == appState.selectedDate;
            final color = has ? Color(moodColors[d.score!] ?? 0xFF7C918C) : t.borderColor;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: '${d.day.month}月${d.day.day}日${has ? moodLabels[d.score!] : '未记'}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _changeDate(d.date),
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? t.accentColor : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Container(
                          width: has ? 14 : 6,
                          height: has ? 14 : 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _weekdayNames[d.day.weekday - 1],
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? t.accentColor : t.textTertiary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (recorded > 0) ...[
          const SizedBox(height: 16),
          Text(
            facts.join('  ·  '),
            style: TextStyle(color: t.textTertiary, fontSize: 12.5),
          ),
        ],
      ],
    );
  }

  /// 页尾：素笺故事 / 树洞，两条文字入口
  Widget _buildMoreLinks(ThemeState t) {
    Widget link(String title, String sub, Widget page) => Semantics(
          button: true,
          label: title,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(color: t.textPrimary, fontSize: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.textTertiary, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: t.textTertiary),
                ],
              ),
            ),
          ),
        );
    return Column(
      children: [
        Divider(color: t.borderColor),
        link('素笺', '写一篇长一点的故事', const StoryListPage()),
        Divider(color: t.borderColor),
        link('树洞', '说给不认识的人听', const TreeholePage()),
        Divider(color: t.borderColor),
      ],
    );
  }

  void _showMoodDetail(Map<String, dynamic> m) {
    final t = context.read<ThemeState>();
    final score = _readMoodScore(m['emotion_type']);
    final notes = m['notes']?.toString() ?? '';
    final color = Color(moodColors[score] ?? 0xFF7C918C);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    moodLabels[score] ?? '',
                    style: XqTypography.headlineSmall.copyWith(color: t.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    TimeUtils.hm(m['created_at']),
                    style: TextStyle(
                      fontSize: 13,
                      color: t.gold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteDayMood(m['id'] as int);
                    },
                    style: TextButton.styleFrom(foregroundColor: t.errorColor),
                    child: const Text('删除'),
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    notes,
                    style: XqTypography.handwrittenBody.copyWith(
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
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
        content: const Text('已删除这条记录'),
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
      if (mounted) context.read<AppState>().bumpMoodRevision();
    } catch (_) {}
  }

  // ── Save Bar ──

  /// 吸底保存条：贴底通栏（surface + 顶部细线），与导航同一语言
  Widget _buildInlineSaveBar(ThemeState t) {
    final status = _saving
        ? '保存中…'
        : _saved
        ? '已保存'
        : _dirty
        ? '有改动未保存'
        : '选一个心情，或写下几句';

    return Container(
      decoration: BoxDecoration(
        color: t.cardColor,
        border: Border(top: BorderSide(color: t.borderColor, width: 0.8)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 16, 10),
      child: Row(
        children: [
          if (_saved) ...[
            Icon(Icons.check, size: 16, color: t.successColor),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _saved ? t.successColor : t.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (_saved)
            OutlinedButton(
              onPressed: _openCardMaker,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(96, 44),
              ),
              child: const Text('制成卡片'),
            )
          else
            FilledButton(
              onPressed: (_dirty && !_saving) ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(96, 44),
              ),
              child: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: t.textOnAccent,
                      ),
                    )
                  : const Text('保存'),
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
        return '平静的一天，也值得写两句';
      case 3:
        return '难过的话，写下来会轻一点';
      case 4:
        return '是什么让你生气了';
      case 5:
        return '把担心的事写下来';
      case 6:
        return '累了，写一句就好';
      case 7:
        return '在期待什么';
      case 8:
        return '想念谁，写给 Ta';
      default:
        return '今天发生了什么';
    }
  }
}
