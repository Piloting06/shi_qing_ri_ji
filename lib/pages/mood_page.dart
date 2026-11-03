import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/xq/xq_icons.dart';
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
import '../widgets/xq/xq_surface.dart';
import '../widgets/xq/xq_paper.dart';
import '../widgets/xq/xq_kit.dart';
import '../utils/solar_term_utils.dart';
import '../widgets/weather_sky.dart' show chineseNumber;
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
      if (mounted) XqToast.error(context, '没连上网，等会儿再试');
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
        final msg = moods.isEmpty ? '这天没有记录' : '这天有 ${moods.length} 条';
        XqToast.info(context, msg);
      }
    } on ApiException catch (e) {
      _hydrating = false;
      if (e.statusCode == 401) return;
      if (mounted) XqToast.error(context, '加载心情失败：${e.message}');
    } catch (_) {
      _hydrating = false;
      if (mounted) XqToast.error(context, '没加载出来，等会儿再试');
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
        HapticFeedback.heavyImpact(); // 印落下
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
            if (mounted) XqToast.info(context, '这一笔可以做成卡片，发给朋友。');
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
      body: XqPaperPage(
        child: SafeArea(
        child: XqRefresh(
          onRefresh: () async {
            await _loadAllMoods();
            if (!context.mounted) return;
            final date = context.read<AppState>().selectedDate;
            final dayMoods = await Api.getMoodsByDate(date);
            if (mounted) setState(() => _dayMoods = dayMoods);
          },
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildHeader(t, appState),
              ),
              const SizedBox(height: 20),
              // 记录区：一张笺（心情颜料 + 签条），一张朱丝栏信笺（书写，钤印）
              XqSurface(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _sectionLabel(t, '此刻的心情'),
                    ),
                    const SizedBox(height: 16),
                    _buildMoodRow(t),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: (_moodScore > 0 && _currentTags.isNotEmpty)
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
                              child: _buildTags(t),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              XqSurface(
                padding: EdgeInsets.zero,
                child: _buildEditor(t),
              ),
              const SizedBox(height: 36),

              // ── 回顾区 ──
              _buildDaySection(t, appState),
              const SizedBox(height: 32),
              _buildRecentWeek(t, appState),
              const SizedBox(height: 32),
              _buildMoreLinks(t),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _sectionLabel(ThemeState t, String text) => Text(
        text,
        style: TextStyle(color: t.textTertiary, fontSize: 12.5, letterSpacing: 1),
      );

  /// 页头：展示体「今天」+ 下一行「周三 · 霜降第十三天」；右侧汉字日期可点选日子，左右翻页
  Widget _buildHeader(ThemeState t, AppState appState) {
    final date = DateTime.tryParse(appState.selectedDate) ?? DateTime.now();
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);
    final canNext = !isToday && date.isBefore(now);
    final title = isToday
        ? '今天'
        : DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))
        ? '昨天'
        : '${chineseNumber(date.month)}月${chineseNumber(date.day)}日';
    final term = currentSolarTerm(date.add(const Duration(hours: 12)));
    final sub = '周${_weekdayNames[date.weekday - 1]} · $term第${chineseNumber(daysIntoSolarTerm(date))}天';

    Widget arrow(XqIcons icon, String label, VoidCallback? onTap) => Semantics(
          button: true,
          label: label,
          child: InkResponse(
            onTap: onTap,
            radius: 22,
            child: SizedBox(
              width: 40,
              height: 44,
              child: XqIcon(
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: XqTypography.displayMedium.copyWith(color: t.textPrimary, fontSize: 32, letterSpacing: 2),
            ),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: t.textTertiary, fontSize: 12.5)),
          ],
        ),
        const Spacer(),
        arrow(XqIcons.back, '前一天', () {
          final d = date.subtract(const Duration(days: 1));
          _changeDate(DateFormat('yyyy-MM-dd').format(d));
        }),
        Semantics(
          button: true,
          label: '选择日期，当前${date.month}月${date.day}日',
          excludeSemantics: true,
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
                '${chineseNumber(date.month)}月${chineseNumber(date.day)}日',
                style: XqTypography.headlineSmall.copyWith(color: t.gold, fontSize: 16),
              ),
            ),
          ),
        ),
        arrow(
          XqIcons.chevronRight,
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

  /// 八种心情：一行颜料（藤黄/石绿/花青…）+ 名字。选中的颜料放大、名字加重、下有一笔墨线。
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
                      height: 34,
                      child: Center(
                        child: AnimatedScale(
                          scale: active ? 1.0 : 0.7,
                          duration: Duration(milliseconds: reduce ? 0 : 200),
                          curve: Curves.easeOutQuart,
                          child: XqPigmentDab(color: color, size: 32, seed: s),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      moodLabels[s] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: active ? t.textPrimary : t.textSecondary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: Duration(milliseconds: reduce ? 0 : 200),
                      width: active ? 14 : 0,
                      height: 1.2,
                      color: t.textPrimary,
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

  /// 标签：签条（细墨框），选中墨底反白
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
                color: sel ? t.accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: sel ? t.accentColor : t.frameColor, width: 0.8),
              ),
              child: Text(
                tag['label'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: sel ? t.textOnAccent : t.textSecondary,
                  fontWeight: sel ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 书写区：朱丝栏信笺，右上角一枝寒枝（芥子园线稿，极淡），楷体正文；保存后右下钤一枚「记」
  Widget _buildEditor(ThemeState t) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Stack(
      key: _editorKey,
      children: [
        Positioned(
          top: 6,
          right: 8,
          child: IgnorePointer(
            child: Image.asset(
              'assets/motifs/branch.png',
              width: 76,
              color: t.ink.withAlpha(t.isDark ? 40 : 34),
              colorBlendMode: BlendMode.srcIn,
              excludeFromSemantics: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 4 * 32 + 8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: LinedPaperPainter(
                      lineColor: t.sealColor.withAlpha(t.isDark ? 70 : 52),
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
          ),
        ),
        // 钤印：保存成功时印从上方落下（1.6 → 1，快进慢停），改动后印撤去
        if (_saved)
          Positioned(
            right: 16,
            bottom: 12,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduce ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuart,
                builder: (context, v, child) => Opacity(
                  opacity: (v * 2.5).clamp(0.0, 1.0),
                  child: Transform.scale(scale: 1.6 - 0.6 * v, child: child),
                ),
                child: XqSeal(char: '记', color: t.sealColor, size: 52, style: XqSealStyle.bai, angle: -0.08),
              ),
            ),
          ),
      ],
    );
  }

  /// 这一天：标题在外，时间线装在一张卡里
  Widget _buildDaySection(ThemeState t, AppState appState) {
    final date = DateTime.tryParse(appState.selectedDate) ?? DateTime.now();
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        XqSectionTitle(
          isToday ? '今天写下的' : '这一天写下的',
          trailing: _dayMoods.isEmpty
              ? null
              : Text('${_dayMoods.length} 笔', style: TextStyle(color: t.textTertiary, fontSize: 12.5)),
        ),
        XqSurface(
          padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
          onTap: _dayMoods.isEmpty ? _scrollToEmotions : null,
          child: _dayMoods.isEmpty
              ? Text(
                  isToday ? '还没写。先选个心情。' : '这天没有记录。',
                  style: TextStyle(color: t.textTertiary, fontSize: 14),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _dayMoods.length; i++)
                      _buildTimelineItem(_dayMoods[i], t, last: i == _dayMoods.length - 1),
                  ],
                ),
        ),
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
                    const SizedBox(height: 3),
                    XqPigmentDab(color: color, size: 13, seed: score),
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
                            fontFamilyFallback: XqTypography.contentFallback,
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const XqSectionTitle('最近七天'),
        XqSurface(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        child: has
                            ? XqPigmentDab(color: color, size: 17, seed: d.score!)
                            : Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              facts.join('  ·  '),
              style: TextStyle(color: t.textTertiary, fontSize: 12.5),
            ),
          ),
        ],
            ],
          ),
        ),
      ],
    );
  }

  /// 页尾：素笺故事 / 树洞
  Widget _buildMoreLinks(ThemeState t) {
    void go(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return XqGroup(
      title: '别的写法',
      children: [
        XqRow(
          icon: XqIcons.write,
          title: '素笺',
          subtitle: '写长一点的',
          onTap: () => go(const StoryListPage()),
        ),
        XqRow(
          icon: XqIcons.leaf,
          title: '树洞',
          subtitle: '匿名写给陌生人',
          onTap: () => go(const TreeholePage()),
        ),
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

  /// 吸底保存条：纸条 + 顶部乌丝栏；右侧是一枚印——可存时朱红白文，点下即「盖印保存」
  Widget _buildInlineSaveBar(ThemeState t) {
    final status = _saving
        ? '正在盖印…'
        : _saved
        ? '已盖印保存'
        : _dirty
        ? '有改动未保存'
        : '选一个心情，或写下几句';
    final canSave = _dirty && !_saving;

    return Container(
      decoration: BoxDecoration(
        color: t.cardColor,
        image: XqPaper.grain(t.paperFiber, strength: t.isDark ? 0.6 : 0.8),
        border: Border(top: BorderSide(color: t.frameColor, width: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _saved ? t.textPrimary : t.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (_saved)
            OutlinedButton(
              onPressed: _openCardMaker,
              style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)),
              child: const Text('制成卡片'),
            )
          else
            Semantics(
              button: true,
              enabled: canSave,
              label: '盖印保存',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canSave ? _save : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '盖印保存',
                        style: TextStyle(
                          color: canSave ? t.textPrimary : t.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedOpacity(
                        opacity: canSave || _saving ? 1 : 0.45,
                        duration: const Duration(milliseconds: 160),
                        child: XqSeal(
                          char: '记',
                          color: canSave || _saving ? t.sealColor : t.textTertiary,
                          size: 44,
                          style: canSave || _saving ? XqSealStyle.bai : XqSealStyle.zhu,
                          angle: -0.04,
                        ),
                      ),
                    ],
                  ),
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
        return '什么事让你开心';
      case 2:
        return '今天过得怎么样';
      case 3:
        return '发生了什么';
      case 4:
        return '是什么让你生气了';
      case 5:
        return '在担心什么';
      case 6:
        return '累的话，写一句也行';
      case 7:
        return '在期待什么';
      case 8:
        return '想谁了';
      default:
        return '今天发生了什么';
    }
  }
}
