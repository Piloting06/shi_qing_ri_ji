import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/mood.dart';
import '../services/story_store.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../widgets/story_card.dart';
import '../api/api_client.dart';
import '../utils/story_chapter.dart';
import '../widgets/xq_empty_state.dart';
import '../widgets/xq_toast.dart';

/// 素笺 · 故事：长文写作与节气章节。
/// 列表 → 编辑（即写即存，显示「已保存 · HH:mm」），系统起笔、用户完笔。
class StoryListPage extends StatefulWidget {
  const StoryListPage({super.key});

  @override
  State<StoryListPage> createState() => _StoryListPageState();
}

class _StoryListPageState extends State<StoryListPage> {
  List<StoryEntry> _entries = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await StoryStore.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openEditor({StoryEntry? entry}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryEditPage(entry: entry),
      ),
    );
    _load();
  }

  /// 生成当前节气的章节起笔稿 → 直接进编辑器
  Future<void> _generateChapter() async {
    if (_generating) return;
    _generating = true;
    try {
      final data = await Api.getAllMoods();
      final moods = ((data['moods'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final chapter = generateSeasonChapter(moods, DateTime.now());
      if (!mounted) return;
      if (chapter == null) {
        XqToast.info(context, '这个节气还没有记录，先写一篇心情吧');
        return;
      }
      HapticFeedback.selectionClick();
      await _openEditor(
        entry: StoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: chapter.title,
          content: chapter.body,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    } catch (_) {
      if (mounted) XqToast.error(context, '生成失败，请稍后再试');
    } finally {
      _generating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.backgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Text(
          '素笺',
          style: XqTypography.headlineLarge.copyWith(color: t.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _generateChapter,
            child: Text(
              '生成节气章',
              style: TextStyle(color: t.accentColor, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () => _openEditor(),
            icon: Icon(Icons.edit_note_rounded, color: t.textPrimary),
            tooltip: '写一篇',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _entries.isEmpty
              ? Center(
                  child: XqEmptyState(
                    icon: Icons.spa_outlined,
                    title: '纸上还空着',
                    subtitle: '写一篇故事，或让节气替你起个头',
                    actionLabel: '写一篇',
                    onAction: () => _openEditor(),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 0), // 用留白代替分隔线
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      return InkWell(
                        onTap: () => _openEditor(entry: e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            border: i == _entries.length - 1
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                      color: t.borderColor.withAlpha(60),
                                      width: 0.5,
                                    ),
                                  ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title.isEmpty ? '无题' : e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'SerifSC',
                                  fontFamilyFallback: [
                                    'Noto Serif SC',
                                    'Songti SC',
                                  ],
                                ),
                              ),
                              if (e.content.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  e.content.replaceAll('\n', ' '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                _metaOf(e),
                                style: TextStyle(
                                  color: t.textTertiary,
                                  fontSize: 11,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _metaOf(StoryEntry e) {
    final updated = DateTime.tryParse(e.updatedAt);
    final time = updated == null
        ? ''
        : '${updated.year}.${updated.month.toString().padLeft(2, '0')}.${updated.day.toString().padLeft(2, '0')}';
    final mood = e.moodScore > 0
        ? '  ·  ${moodLabels[e.moodScore] ?? ''}'
        : '';
    return '$time$mood';
  }
}

/// 编辑页：即写即存。自动保存（800ms 防抖），顶部显示「已保存 · HH:mm」。
class StoryEditPage extends StatefulWidget {
  final StoryEntry? entry;
  const StoryEditPage({super.key, this.entry});

  @override
  State<StoryEditPage> createState() => _StoryEditPageState();
}

class _StoryEditPageState extends State<StoryEditPage> {
  late StoryEntry _entry;
  late final _titleCtrl = TextEditingController(text: _entry.title);
  late final _contentCtrl = TextEditingController(text: _entry.content);
  Timer? _debounce;
  String? _savedAt; // '14:32'
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry ??
        StoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: '',
          content: '',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    _debounce?.cancel();
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) return; // 全空不落盘
    _entry = await StoryStore.save(
      _entry.copyWith(
        title: title,
        content: content,
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _savedAt =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删掉这篇？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: Colors.red.withAlpha(200))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _debounce?.cancel();
    await StoryStore.delete(_entry.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    final serif = TextStyle(
      fontFamily: 'SerifSC',
      fontFamilyFallback: ['Noto Serif SC', 'Songti SC'],
    );
    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.backgroundColor,
        elevation: 0,
        toolbarHeight: 48,
        leading: BackButton(color: t.textSecondary),
        title: Text(
          _savedAt == null ? (_dirty ? '未保存' : '') : '已保存 · $_savedAt',
          style: TextStyle(color: t.textTertiary, fontSize: 12),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryCardPreviewPage(
                    title: _titleCtrl.text.trim(),
                    body: _contentCtrl.text.trim(),
                    dateText: _savedAt == null
                        ? DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '.')
                        : (DateTime.tryParse(_entry.updatedAt) ?? DateTime.now())
                            .toIso8601String()
                            .substring(0, 10)
                            .replaceAll('-', '.'),
                  ),
                ),
              );
            },
            icon: Icon(Icons.style_outlined, size: 20, color: t.textPrimary),
            tooltip: '制成故事卡',
          ),
          if (widget.entry != null)
            IconButton(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.red.withAlpha(180)),
              tooltip: '删除',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    onChanged: (_) {
                      setState(() => _dirty = true);
                      _onChanged();
                    },
                    maxLines: 1,
                    style: serif.copyWith(
                      color: t.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    cursorColor: t.accentColor,
                    decoration: InputDecoration(
                      hintText: '题',
                      hintStyle: serif.copyWith(
                        color: t.textTertiary.withAlpha(120),
                        fontSize: 22,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                  Container(
                    width: 26,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    height: 1,
                    color: t.borderColor,
                  ),
                  TextField(
                    controller: _contentCtrl,
                    onChanged: (_) {
                      setState(() => _dirty = true);
                      _onChanged();
                    },
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: XqTypography.handwrittenBody.copyWith(
                      color: t.textPrimary,
                      fontSize: 16.5,
                      height: 1.85,
                    ),
                    cursorColor: t.accentColor,
                    decoration: InputDecoration(
                      hintText: '写下来，晴天多记一笔',
                      hintStyle: XqTypography.handwrittenBody.copyWith(
                        color: t.textTertiary.withAlpha(120),
                        fontSize: 16.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 吸底状态栏：避开键盘与安全区
          Container(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(
              color: t.cardColor,
              border: Border(top: BorderSide(color: t.borderColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Text(
                  _dirty ? '落笔中…' : (_savedAt == null ? '素笺' : '已收好'),
                  style: TextStyle(
                    color: t.textTertiary,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _save,
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: t.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
