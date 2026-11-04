import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'xq/xq_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../api/api_client.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
import '../theme/xq_typography.dart';
import '../constants/mood.dart';
import 'mood_card/card_album_store.dart';
import 'mood_card/mood_card_data.dart';
import 'mood_card/mood_card_registry.dart';
import 'xq_toast.dart';
import 'xq/xq_paper.dart';

class MoodCardMaker extends StatefulWidget {
  final String date;
  final String moodLabel;
  final int moodScore;
  final String text;
  final List<String> tags;
  final ThemeState theme;
  final String? createdAt;
  final String? weatherText;
  final String? cityName;
  final String? temperature;

  const MoodCardMaker({
    super.key,
    required this.date,
    required this.moodLabel,
    required this.moodScore,
    required this.text,
    required this.tags,
    required this.theme,
    this.createdAt,
    this.weatherText,
    this.cityName,
    this.temperature,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String date,
    required String moodLabel,
    required int moodScore,
    required String text,
    required List<String> tags,
    String? createdAt,
    String? weatherText,
    String? cityName,
    String? temperature,
  }) {
    final t = context.read<ThemeState>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MoodCardMaker(
        date: date,
        moodLabel: moodLabel,
        moodScore: moodScore,
        text: text,
        tags: tags,
        theme: t,
        createdAt: createdAt,
        weatherText: weatherText,
        cityName: cityName,
        temperature: temperature,
      ),
    );
  }

  @override
  State<MoodCardMaker> createState() => _MoodCardMakerState();
}

class _MoodCardMakerState extends State<MoodCardMaker> {
  static const _templatePrefKey = 'card_template_id';
  static const _qrPrefKey = 'share_with_qr';
  static const _landingUrl = 'https://xqrj.glxgo.xin/?from=card';

  final _repaintKey = GlobalKey();
  final _pageController = PageController();
  late final _bodyCtrl = TextEditingController(text: widget.text);
  bool _saving = false;
  bool _editMode = false;
  bool _squareCard = false; // false=圆角(温润), true=方形(方寸)
  int _templateIndex = 0;
  bool _shareWithQr = false;
  String? _weatherOverride; // null=跟随真实天气
  bool _squareRatio = false; // false=竖版 true=1:1方图
  double _bodyScale = 1.0; // 正文字号 1.0 标准 / 0.9 小
  int _streak = 0;
  List<MoodDay> _week = const [];
  List<Map<String, dynamic>> _historyMoods = const [];
  late String _bodyText = widget.text;

  // Edit options
  String _dateStyle = 'cn_full'; // cn_full | en_full | slash | dot
  String _watermark = 'en'; // cn | en | sq | sqrj | xiaoqing
  String _username = '';
  int? _overrideMoodScore;
  final List<String> _overrideTags = [];
  bool _showEmojiPicker = false;
  bool _showTagPicker = false;

  MoodCardTemplateSpec get _spec => moodCardTemplates[_templateIndex];
  Color get _accentColor => _spec.dotColors.first;

  int get _activeMoodScore => _overrideMoodScore ?? widget.moodScore;
  List<String> get _activeTags => _overrideTags.isNotEmpty ? _overrideTags : widget.tags;

  String get _formattedDate {
    final d = DateTime.tryParse(widget.date) ?? DateTime.now();
    final weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final enWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final enMonths = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return switch (_dateStyle) {
      'en_full' => '${enMonths[d.month]} ${d.day}, ${d.year} ${enWeekdays[d.weekday - 1]}',
      'slash' => '${d.month}/${d.day}',
      'dot' => '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}',
      _ => '${d.year}年${d.month}月${d.day}日 ${weekdays[d.weekday - 1]}',
    };
  }

  String? get _effectiveWeather => _weatherOverride ?? widget.weatherText;

  MoodCardData _cardDataFor(double height) => MoodCardData(
        dateText: _formattedDate,
        rawDate: widget.date,
        moodScore: _activeMoodScore,
        moodEmoji: moodEmojis[_activeMoodScore] ?? '😊',
        moodLabel: moodLabels[_activeMoodScore] ?? widget.moodLabel,
        moodEn: _moodEnglishFor(_activeMoodScore),
        bodyText: _bodyText,
        tags: _activeTags,
        username: _username,
        watermark: _watermark,
        weatherText: _effectiveWeather,
        cityName: widget.cityName,
        temperature: widget.temperature,
        square: _squareCard,
        streakDays: _streak,
        week: _week,
        height: height,
        bodyScale: _bodyScale,
      );

  String _moodEnglishFor(int score) => switch (score) {
    1 => 'JOY',
    2 => 'CALM',
    3 => 'LOW',
    4 => 'ANGER',
    5 => 'ANXIETY',
    6 => 'TIRED',
    7 => 'HOPE',
    8 => 'MISSING',
    _ => 'MOOD',
  };

  @override
  void initState() {
    super.initState();
    _restorePrefs();
    _loadStats();
  }

  /// 拉取全部心情记录，计算连续天数与最近7天（火焰卡/周历卡用）
  Future<void> _loadStats() async {
    try {
      final data = await Api.getAllMoods();
      final moods = (data['moods'] as List?) ?? const [];
      final stats = computeMoodStats(
        moods.whereType<Map<String, dynamic>>().toList(),
        DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _streak = stats.streak;
        _week = stats.week;
        _historyMoods = moods.whereType<Map<String, dynamic>>().toList();
      });
    } catch (_) {
      // 统计加载失败不影响单日卡片
    }
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    // 没选过模板时，默认用和 App 当前同一张纸的「笺」
    final savedId = prefs.getString(_templatePrefKey) ?? widget.theme.palette.id;
    final idx = moodCardTemplates.indexWhere((t) => t.id == savedId);
    setState(() {
      if (idx >= 0) _templateIndex = idx;
      _shareWithQr = prefs.getBool(_qrPrefKey) ?? false;
    });
    if (idx >= 0 && _pageController.hasClients) {
      _pageController.jumpToPage(idx);
    }
  }

  void _selectTemplate(int index, {bool animate = true}) {
    HapticFeedback.selectionClick();
    setState(() => _templateIndex = index);
    prefsSet(_templatePrefKey, moodCardTemplates[index].id);
    if (animate && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> prefsSet(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _toggleQr(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _shareWithQr = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_qrPrefKey, value);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        p.join(
          dir.path,
          'mood_card_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Gal.putImage(file.path);
      // 归档进卡片册（失败不影响保存）
      await CardAlbumStore.archive(
        sourceFilePath: file.path,
        date: widget.date,
        moodScore: _activeMoodScore,
        templateId: _spec.id,
        square: _squareRatio,
      );
      if (mounted) {
        XqToast.success(context, '卡片已保存到相册');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) XqToast.error(context, '保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'mood_card_share.png'));
      await file.writeAsBytes(byteData.buffer.asUint8List());
      final text = _shareWithQr
          ? '拾晴日记 · ${widget.date}\n${widget.moodLabel} — ${widget.text.isNotEmpty ? widget.text : "天气加心情"}\n$_landingUrl'
          : '拾晴日记 · ${widget.date}\n${widget.moodLabel} — ${widget.text.isNotEmpty ? widget.text : "天气加心情"}';
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: text),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {}
  }

  Widget _buildEditRow(String label, List<Widget> chips) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: widget.theme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: chips.isNotEmpty
              ? Row(children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)).toList())
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildChip(String text, String value) {
    final isActive =
        value == _dateStyle || value == _watermark;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (const ['cn_full', 'en_full', 'slash', 'dot'].contains(value)) {
            _dateStyle = value;
          } else {
            _watermark = value;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? _accentColor : widget.theme.borderColor,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? _accentColor : widget.theme.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherChip(String text, String? weather) {
    final isActive = _weatherOverride == weather;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _weatherOverride = weather);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? _accentColor : widget.theme.borderColor,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? _accentColor : widget.theme.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final spec = moodCardTemplates[index];
    final active = _templateIndex == index;
    return GestureDetector(
      onTap: () => _selectTemplate(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: active ? 42 : 36,
        height: active ? 42 : 36,
        margin: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: spec.dotColors),
          border: Border.all(
            color: widget.theme.cardColor,
            width: active ? 3 : 2,
          ),
        ),
        child: active
            ? const Center(
                child: XqIcon(XqIcons.check, size: 16, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildStyleToggle(ThemeState theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStylePill(theme, '温润', false),
        const SizedBox(width: 8),
        _buildStylePill(theme, '方寸', true),
      ],
    );
  }

  Widget _buildStylePill(ThemeState theme, String label, bool square) {
    final isActive = _squareCard == square;
    return GestureDetector(
      onTap: () => setState(() => _squareCard = square),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? _accentColor.withAlpha(120) : theme.borderColor,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? _accentColor : theme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionPill(
    ThemeState theme,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? _accentColor.withAlpha(120) : theme.borderColor,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? _accentColor : theme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRatioToggle(ThemeState theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildOptionPill(
            theme, '竖版', !_squareRatio, () => setState(() => _squareRatio = false)),
        const SizedBox(width: 8),
        _buildOptionPill(
            theme, '方图', _squareRatio, () => setState(() => _squareRatio = true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetTheme = widget.theme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // 方图让预览区变高，弹层随之加高并封顶
    final cardHeight =
        _squareRatio ? math.min(screenWidth - 32, 420.0) : 216.0;
    final sheetHeight = math.min(
      (_editMode ? 0.85 : 0.72) * screenHeight +
          (_squareRatio ? cardHeight - 216.0 : 0.0),
      screenHeight * 0.94,
    );
    final d = DateTime.tryParse(widget.date) ?? DateTime.now();
    const enMonths = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: sheetHeight,
      decoration: BoxDecoration(
        color: sheetTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    '制成一张卡片',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: sheetTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: () => setState(() => _editMode = !_editMode),
                    icon: XqIcon(
                      _editMode ? XqIcons.check : XqIcons.write,
                      color: _editMode ? _accentColor : sheetTheme.textSecondary,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: XqIcon(XqIcons.close,
                      color: sheetTheme.textSecondary,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _editMode ? '编辑卡片内容' : '左右滑动或点色点，切换 ${_spec.name}',
              style: TextStyle(color: sheetTheme.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Template dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(moodCardTemplates.length, _buildDot),
            ),
            if (!_editMode) ...[
              const SizedBox(height: 10),
              _buildStyleToggle(sheetTheme),
              const SizedBox(height: 8),
              _buildRatioToggle(sheetTheme),
            ],

            // Edit panel (scrollable when expanded)
            if (_editMode)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildStyleToggle(sheetTheme),
                      const SizedBox(height: 8),
                      _buildRatioToggle(sheetTheme),
                      if (_spec.id == 'sunny') ...[
                        const SizedBox(height: 10),
                        _buildEditRow('天气图案', [
                          _buildWeatherChip('自动', null),
                          _buildWeatherChip('晴', '晴'),
                          _buildWeatherChip('多云', '多云'),
                          _buildWeatherChip('阴', '阴'),
                          _buildWeatherChip('雨', '雨'),
                          _buildWeatherChip('雪', '雪'),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      // Date format
                      _buildEditRow('日期格式', [
                        _buildChip('${d.year}年${d.month}月${d.day}日', 'cn_full'),
                        _buildChip('${enMonths[d.month]} ${d.day}', 'en_full'),
                        _buildChip('${d.month}/${d.day}', 'slash'),
                        _buildChip('${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}', 'dot'),
                      ]),
                      const SizedBox(height: 10),
                      // Watermark
                      _buildEditRow('水印', [
                        _buildChip('拾晴日记', 'cn'),
                        _buildChip('SHI QING', 'en'),
                        _buildChip('s q r j', 'sqrj'),
                        _buildChip('小晴', 'xiaoqing'),
                      ]),
                      const SizedBox(height: 10),
                      // Username
                      _buildEditRow('用户名', []),
                      const SizedBox(height: 4),
                      TextField(
                        onChanged: (v) => setState(() => _username = v),
                        style: TextStyle(color: sheetTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: '用户名',
                          hintText: '可选，留空则不显示',
                          labelStyle: TextStyle(color: sheetTheme.textTertiary, fontSize: 12),
                          hintStyle: TextStyle(color: sheetTheme.textTertiary, fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(XqDecorations.radiusSmall),
                            borderSide: BorderSide(color: sheetTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(XqDecorations.radiusSmall),
                            borderSide: BorderSide(color: sheetTheme.borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 正文
                      _buildEditRow('正文', [
                        GestureDetector(
                          onTap: () {
                            final line = inspirationLine(
                              weather: _effectiveWeather,
                              moodScore: _activeMoodScore,
                              moodLabel:
                                  moodLabels[_activeMoodScore] ?? widget.moodLabel,
                              streak: _streak,
                              history: _historyMoods,
                            );
                            if (line == null) return;
                            HapticFeedback.selectionClick();
                            setState(() {
                              _bodyText = _bodyText.trim().isEmpty
                                  ? line
                                  : '${_bodyText.trim()} $line';
                              _bodyCtrl.text = _bodyText;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              XqIcon(XqIcons.spark,
                                  size: 13, color: sheetTheme.gold),
                              const SizedBox(width: 3),
                              Text(
                                '心晴签',
                                style: TextStyle(
                                  color: sheetTheme.gold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _bodyCtrl,
                        onChanged: (v) => _bodyText = v,
                        maxLines: 2,
                        style: TextStyle(color: sheetTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '写点卡片上的话',
                          hintStyle: TextStyle(color: sheetTheme.textTertiary, fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(XqDecorations.radiusSmall),
                            borderSide: BorderSide(color: sheetTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(XqDecorations.radiusSmall),
                            borderSide: BorderSide(color: sheetTheme.borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildEditRow('字号', [
                        _buildOptionPill(sheetTheme, '标准', _bodyScale == 1.0,
                            () => setState(() => _bodyScale = 1.0)),
                        _buildOptionPill(sheetTheme, '小', _bodyScale == 0.9,
                            () => setState(() => _bodyScale = 0.9)),
                      ]),
                      const SizedBox(height: 10),
                      // 心情选择（与标签选择互斥）
                      GestureDetector(
                        onTap: () => setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                          if (_showEmojiPicker) _showTagPicker = false;
                        }),
                        child: _buildEditRow('情绪', [
                          XqPigmentDab(color: Color(moodColors[_activeMoodScore] ?? 0xFF7A7871), size: 16, seed: _activeMoodScore),
                          const SizedBox(width: 4),
                          Text(
                            moodLabels[_activeMoodScore] ?? '',
                            style: TextStyle(color: _accentColor, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          XqIcon(_showEmojiPicker ? XqIcons.chevronUp : XqIcons.chevronDown, size: 18, color: sheetTheme.textTertiary),
                        ]),
                      ),
                      if (_showEmojiPicker) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: moodLabels.entries.map((e) {
                            final isActive = e.key == _activeMoodScore;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _overrideMoodScore = e.key;
                                _showEmojiPicker = false;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive ? _accentColor.withAlpha(20) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isActive ? _accentColor : sheetTheme.borderColor,
                                    width: isActive ? 1.2 : 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    XqPigmentDab(color: Color(moodColors[e.key] ?? 0xFF7A7871), size: 14, seed: e.key),
                                    const SizedBox(width: 5),
                                    Text(e.value, style: TextStyle(fontSize: 12, color: sheetTheme.textPrimary)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Tag picker (mutually exclusive with emoji picker)
                      GestureDetector(
                        onTap: () => setState(() {
                          _showTagPicker = !_showTagPicker;
                          if (_showTagPicker) _showEmojiPicker = false;
                        }),
                        child: _buildEditRow('标签', [
                          Text(
                            _activeTags.isEmpty ? '点击选择' : _activeTags.take(2).join(' · '),
                            style: TextStyle(
                              color: _activeTags.isEmpty ? sheetTheme.textTertiary : _accentColor,
                              fontSize: 12,
                            ),
                          ),
                          XqIcon(_showTagPicker ? XqIcons.chevronUp : XqIcons.chevronDown, size: 18, color: sheetTheme.textTertiary),
                        ]),
                      ),
                      if (_showTagPicker) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _allTags.map((tag) {
                            final isActive = _overrideTags.contains(tag);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (isActive) {
                                  _overrideTags.remove(tag);
                                } else {
                                  _overrideTags.add(tag);
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isActive ? _accentColor.withAlpha(20) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive ? _accentColor : sheetTheme.borderColor,
                                    width: isActive ? 1.2 : 0.8,
                                  ),
                                ),
                                child: Text(tag, style: TextStyle(fontSize: 11, color: isActive ? _accentColor : sheetTheme.textSecondary)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // QR toggle
                      GestureDetector(
                        onTap: () => _toggleQr(!_shareWithQr),
                        child: _buildEditRow('分享附带下载二维码', [
                          Text(
                            _shareWithQr ? '已开启 · 扫码可下载 App' : '已关闭',
                            style: TextStyle(
                              color: _shareWithQr ? _accentColor : sheetTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          XqIcon(
                            _shareWithQr
                                ? XqIcons.qr
                                : XqIcons.qr,
                            size: 18,
                            color: _shareWithQr ? _accentColor : sheetTheme.textTertiary,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Card preview (fixed height, swipeable templates)
            SizedBox(
              height: cardHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: moodCardTemplates.length,
                onPageChanged: (i) => _selectTemplate(i, animate: false),
                itemBuilder: (context, i) {
                  final card = RepaintBoundary(
                    key: i == _templateIndex ? _repaintKey : GlobalKey(),
                    // 卡片属内容层：整张卡默认楷体，与界面黑体分开
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontFamily: XqTypography.content,
                        fontFamilyFallback: XqTypography.contentFallback,
                      ),
                      child: moodCardTemplates[i].buildCard(_cardDataFor(cardHeight)),
                    ),
                  );
                  if (i != _templateIndex || !_shareWithQr) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: card,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      children: [
                        card,
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _landingUrl,
                              version: QrVersions.auto,
                              size: 44,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: sheetTheme.borderColor.withAlpha(80),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const XqIcon(XqIcons.save, size: 18),
                            label: const Text('保存到相册'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _accentColor,
                              side: BorderSide(
                                color: _accentColor.withAlpha(120),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _share,
                            icon: const XqIcon(XqIcons.share, size: 18),
                            label: const Text('分享给朋友'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
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
    );
  }
}

const _allTags = [
  '达成目标', '学习进步', '运动健身', '美食享受', '旅行出游',
  '朋友聚会', '家人陪伴', '独处时光', '工作顺利', '创作表达',
  '自然风景', '音乐电影', '购物开心', '睡眠充足', '小确幸',
];
