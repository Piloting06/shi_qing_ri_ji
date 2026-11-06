import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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
import '../constants/mood.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import 'mood_card/card_album_store.dart';
import 'mood_card/card_kit.dart';
import 'mood_card/mood_card_data.dart';
import 'mood_card/mood_card_registry.dart';
import 'weather_sky.dart' show chineseNumber;
import 'xq/xq_icons.dart';
import 'xq/xq_paper.dart';
import 'xq_toast.dart';

/// 做一张卡：上面是卡（左右滑换样式），下面一行样式签，再往下是能改的几样东西，最底下存 / 发。
/// 编辑项常驻，不藏在铅笔按钮后面；选项都是签条（细墨框，选中墨底反白）。
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
  static const _datePrefKey = 'card_date_style';
  static const _markPrefKey = 'card_watermark';
  static const _namePrefKey = 'card_username';
  static const _landingUrl = 'https://xqrj.glxgo.xin/?from=card';

  // 每页固定一个导出 key：翻页时不用拆掉重建可见页
  final _cardKeys = List.generate(moodCardTemplates.length, (_) => GlobalKey());
  final _pageController = PageController();
  bool _programmaticPaging = false; // 点样式条 / 恢复上次样式时的翻页，不当作用户滑动
  late final _bodyCtrl = TextEditingController(text: widget.text);
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  int _templateIndex = 0;
  bool _shareWithQr = false;
  bool _square = false; // 方图
  double _bodyScale = 1.0;
  List<MoodDay> _week = const [];
  int _streak = 0;
  List<Map<String, dynamic>> _history = const [];
  late String _bodyText = widget.text;
  String _dateStyle = 'hanzi'; // hanzi 二〇二六年十一月五日 | cn 2026年11月5日 | short 十一月五日
  String _watermark = 'cn'; // cn | xiaoqing | none
  int? _moodOverride;
  late final List<String> _tags = [...widget.tags];

  ThemeState get t => widget.theme;
  MoodCardTemplateSpec get _spec => moodCardTemplates[_templateIndex];
  int get _mood => _moodOverride ?? widget.moodScore;

  String get _dateText {
    final d = DateTime.tryParse(widget.date) ?? DateTime.now();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return switch (_dateStyle) {
      'cn' => '${d.year}年${d.month}月${d.day}日 ${weekdays[d.weekday - 1]}',
      'short' => '${chineseNumber(d.month)}月${chineseNumber(d.day)}日 ${weekdays[d.weekday - 1]}',
      _ => '${hanziYear(d.year)}年${chineseNumber(d.month)}月${chineseNumber(d.day)}日',
    };
  }

  MoodCardData _data(double height) => MoodCardData(
        dateText: _dateText,
        rawDate: widget.date,
        moodScore: _mood,
        moodLabel: moodLabels[_mood] ?? widget.moodLabel,
        bodyText: _bodyText,
        tags: _tags,
        username: _nameCtrl.text,
        watermark: _watermark,
        weatherText: widget.weatherText,
        cityName: widget.cityName,
        temperature: widget.temperature,
        square: _square,
        streakDays: _streak,
        week: _week,
        height: height,
        bodyScale: _bodyScale,
      );

  @override
  void initState() {
    super.initState();
    _restorePrefs();
    _loadStats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bodyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final data = await Api.getAllMoods();
      final moods = ((data['moods'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
      final stats = computeMoodStats(moods, DateTime.now());
      if (!mounted) return;
      setState(() {
        _streak = stats.streak;
        _week = stats.week;
        _history = moods;
      });
    } catch (_) {
      // 统计拉不到时，七日卡显示空格子，不影响其它样式
    }
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    // 没选过样式时，默认用和 App 当前同一张纸的「笺」
    final savedId = prefs.getString(_templatePrefKey) ?? t.palette.id;
    final idx = moodCardTemplates.indexWhere((x) => x.id == savedId);
    setState(() {
      if (idx >= 0) _templateIndex = idx;
      _shareWithQr = prefs.getBool(_qrPrefKey) ?? false;
      final date = prefs.getString(_datePrefKey);
      _dateStyle = const {'hanzi', 'cn', 'short'}.contains(date) ? date! : 'hanzi';
      final mark = prefs.getString(_markPrefKey);
      _watermark = const {'cn', 'xiaoqing', 'none'}.contains(mark) ? mark! : 'cn';
      _nameCtrl.text = prefs.getString(_namePrefKey) ?? '';
    });
    if (idx >= 0 && _pageController.hasClients) {
      _programmaticPaging = true;
      _pageController.jumpToPage(idx);
      WidgetsBinding.instance.addPostFrameCallback((_) => _programmaticPaging = false);
    }
  }

  Future<void> _remember(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (value) {
      case final String s:
        await prefs.setString(key, s);
      case final bool b:
        await prefs.setBool(key, b);
    }
  }

  void _selectTemplate(int index, {bool animate = true}) {
    if (index == _templateIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _templateIndex = index);
    _remember(_templatePrefKey, moodCardTemplates[index].id);
    if (animate && _pageController.hasClients) {
      // 跨多页跳转时 onPageChanged 会逐页触发，期间不再重复震动、写偏好
      _programmaticPaging = true;
      _pageController
          .animateToPage(index, duration: const Duration(milliseconds: 280), curve: Curves.easeOutQuart)
          .whenComplete(() => _programmaticPaging = false);
    }
  }

  Future<File?> _render(String name) async {
    final boundary = _cardKeys[_templateIndex].currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final file = await _render('mood_card_${DateTime.now().millisecondsSinceEpoch}.png');
      if (file == null) return;
      await Gal.putImage(file.path);
      await CardAlbumStore.archive(
        sourceFilePath: file.path,
        date: widget.date,
        moodScore: _mood,
        templateId: _spec.id,
        square: _square,
      );
      if (mounted) {
        XqToast.success(context, '已存进相册');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) XqToast.error(context, '没存上，看看是不是没给相册权限');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    try {
      final file = await _render('mood_card_share.png');
      if (file == null) return;
      final words = _bodyText.trim().isEmpty ? '' : '：${_bodyText.trim()}';
      final text = '拾晴日记 · ${hanziMonthDay(widget.date)}\n${moodLabels[_mood] ?? widget.moodLabel}$words'
          '${_shareWithQr ? '\n$_landingUrl' : ''}';
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
      if (mounted) Navigator.pop(context);
    } catch (_) {}
  }

  void _inspire() {
    final line = inspirationLine(
      weather: widget.weatherText,
      moodScore: _mood,
      moodLabel: moodLabels[_mood] ?? widget.moodLabel,
      streak: _streak,
      history: _history,
    );
    if (line == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _bodyText = _bodyText.trim().isEmpty ? line : '${_bodyText.trim()}　$line';
      _bodyCtrl.text = _bodyText;
    });
  }

  // ── 小零件 ──

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? t.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? t.accentColor : t.controlBorder.withAlpha(150), width: 0.8),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: active ? t.textOnAccent : t.textSecondary)),
      ),
    );
  }

  /// 单选一组签条
  Widget _choices<T>(List<(T, String)> items, T value, ValueChanged<T> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final (v, label) in items) _chip(label, v == value, () => onPick(v))],
      );

  Widget _field(String label, Widget child, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: XqTypography.headlineSmall.copyWith(color: t.textPrimary, fontSize: 15)),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _templateStrip() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: moodCardTemplates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final s = moodCardTemplates[i];
          final active = i == _templateIndex;
          return Semantics(
            button: true,
            selected: active,
            label: '${s.name}，${s.label}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _selectTemplate(i),
              child: Column(
                children: [
                  // 样纸：卡面底色 + 一个主色方点
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 30,
                    decoration: BoxDecoration(
                      color: s.dotColors[1],
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: active ? t.textPrimary : t.frameColor, width: active ? 1.2 : 0.6),
                    ),
                    alignment: const Alignment(0.6, 0.5),
                    child: Container(width: 7, height: 7, color: s.dotColors[0]),
                  ),
                  const SizedBox(height: 6),
                  Text(s.name, style: TextStyle(fontSize: 12, color: active ? t.textPrimary : t.textTertiary)),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 12 : 0,
                    height: 1.2,
                    color: t.textPrimary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _moodRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final e in moodLabels.entries)
          Semantics(
            button: true,
            selected: e.key == _mood,
            label: e.value,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _moodOverride = e.key);
              },
              child: Column(
                children: [
                  XqPigmentDab(color: Color(moodColors[e.key]!), size: 24, seed: e.key),
                  const SizedBox(height: 4),
                  Text(e.value, style: TextStyle(fontSize: 11.5, color: e.key == _mood ? t.textPrimary : t.textTertiary)),
                  const SizedBox(height: 3),
                  Container(width: 12, height: 1.2, color: e.key == _mood ? t.textPrimary : Colors.transparent),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cardWidth = mq.size.width - 32;
    final cardHeight = _square ? math.min(cardWidth, 420.0) : 216.0;
    final d = DateTime.tryParse(widget.date) ?? DateTime.now();
    final tagPool = {...widget.tags, ..._tags, ..._allTags}.toList();

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: t.cardColor,
        image: XqPaper.grain(t.paperFiber, strength: t.isDark ? 0.6 : 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 32, height: 3, decoration: BoxDecoration(color: t.borderColor, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  Text('做一张卡', style: XqTypography.displaySmall.copyWith(color: t.textPrimary, fontSize: 22)),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: XqIcon(XqIcons.close, color: t.textSecondary, size: 22),
                  ),
                ],
              ),
            ),
            // 卡：左右滑换样式。二维码画在导出边界里，存出来的图上也有
            SizedBox(
              height: cardHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: moodCardTemplates.length,
                onPageChanged: (i) {
                  if (!_programmaticPaging) _selectTemplate(i, animate: false);
                },
                itemBuilder: (context, i) {
                  // 卡片是导出的图片，尺寸固定：不跟系统字号放大，免得字挤出卡面
                  return MediaQuery.withNoTextScaling(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RepaintBoundary(
                        key: _cardKeys[i],
                        child: Stack(
                          children: [
                            DefaultTextStyle.merge(
                              style: const TextStyle(fontFamily: XqTypography.content, fontFamilyFallback: XqTypography.contentFallback),
                              child: moodCardTemplates[i].buildCard(_data(cardHeight)),
                            ),
                            // 二维码画在导出边界里，存出来、发出去的图上都有；用 Visibility 保持树结构不变
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Visibility(
                                visible: _shareWithQr,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBF8F1),
                                    border: Border.all(color: const Color(0xFFC6BDAA), width: 0.6),
                                  ),
                                  child: QrImageView(data: _landingUrl, version: QrVersions.auto, size: 40, padding: EdgeInsets.zero),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _templateStrip(),
            Container(height: 0.6, color: t.borderColor, margin: const EdgeInsets.only(top: 4)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                children: [
                  _field(
                    '写的话',
                    TextField(
                      controller: _bodyCtrl,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 140,
                      onChanged: (v) => setState(() => _bodyText = v),
                      style: kaiStyle(15, t.textPrimary, height: 1.6),
                      decoration: InputDecoration(
                        fillColor: t.sunkenColor,
                        counterStyle: TextStyle(color: t.textTertiary, fontSize: 11),
                      ),
                    ),
                    trailing: Semantics(
                      button: true,
                      label: '添一句',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _inspire,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              XqIcon(XqIcons.spark, size: 14, color: t.gold),
                              const SizedBox(width: 3),
                              Text('添一句', style: TextStyle(color: t.gold, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _field('心情', _moodRow()),
                  _field(
                    '小标签',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final x in tagPool.take(12))
                          _chip(x, _tags.contains(x), () {
                            setState(() {
                              if (_tags.contains(x)) {
                                _tags.remove(x);
                              } else if (_tags.length < 2) {
                                _tags.add(x);
                              }
                            });
                          }),
                      ],
                    ),
                  ),
                  _field(
                    '版式',
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _choices<bool>(const [(false, '横幅'), (true, '方图')], _square, (v) => setState(() => _square = v)),
                        _choices<double>(const [(1.0, '字大'), (0.9, '字小')], _bodyScale, (v) => setState(() => _bodyScale = v)),
                      ],
                    ),
                  ),
                  _field(
                    '日期',
                    _choices<String>(
                      [
                        ('hanzi', '${hanziYear(d.year)}年${chineseNumber(d.month)}月${chineseNumber(d.day)}日'),
                        ('cn', '${d.year}年${d.month}月${d.day}日'),
                        ('short', '${chineseNumber(d.month)}月${chineseNumber(d.day)}日'),
                      ],
                      _dateStyle,
                      (v) {
                        setState(() => _dateStyle = v);
                        _remember(_datePrefKey, v);
                      },
                    ),
                  ),
                  _field(
                    '落款',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _choices<String>(
                          const [('cn', '拾晴日记'), ('xiaoqing', '小晴'), ('none', '不落款')],
                          _watermark,
                          (v) {
                            setState(() => _watermark = v);
                            _remember(_markPrefKey, v);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameCtrl,
                          maxLength: 8,
                          onChanged: (v) {
                            setState(() {});
                            _remember(_namePrefKey, v.trim());
                          },
                          style: TextStyle(color: t.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '署名',
                            isDense: true,
                            fillColor: t.sunkenColor,
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('附二维码', style: TextStyle(color: t.textSecondary, fontSize: 13.5)),
                      ),
                      Switch(
                        value: _shareWithQr,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _shareWithQr = v);
                          _remember(_qrPrefKey, v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 0.6, color: t.borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const XqIcon(XqIcons.save, size: 18),
                      label: const Text('存进相册'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _share,
                      icon: const XqIcon(XqIcons.share, size: 18),
                      label: const Text('发给朋友'),
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
}

const _allTags = [
  '家人', '朋友', '独处', '工作', '学习', '运动', '吃饭', '出门',
  '读书', '音乐', '睡觉', '看天',
];
