import '../widgets/xq_toast.dart';
import '../widgets/xq_empty_state.dart';
import '../utils/time_utils.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/xq/xq_kit.dart';
import '../widgets/xq/xq_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/helpers.dart';
import '../api/api_client.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
import '../theme/xq_typography.dart';
import '../widgets/ink_writing_loader.dart';

class TreeholePage extends StatefulWidget {
  const TreeholePage({super.key});
  @override
  State<TreeholePage> createState() => _TreeholePageState();
}

class _TreeholePageState extends State<TreeholePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _posting = false;
  String? _error;
  int _page = 1;
  String? _postError;
  bool _active = true;
  final _msgCtrl = TextEditingController();
  Timer? _pollTimer;
  late AnimationController _refreshCtrl;

  // Comments
  final Map<int, List<Map<String, dynamic>>> _comments = {};
  final Set<int> _commentsLoading = {};
  final Set<int> _commentsExpanded = {};
  final Map<int, TextEditingController> _commentCtrls = {};
  final Set<int> _commentPosting = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _msgCtrl.addListener(_onDraftChanged);
    _refreshCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _active && !_posting) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _msgCtrl.removeListener(_onDraftChanged);
    _msgCtrl.dispose();
    _refreshCtrl.dispose();
    for (final c in _commentCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _load(quiet: true);
    }
  }

  void _onDraftChanged() {
    if (!mounted) return;
    if (_postError != null) {
      setState(() => _postError = null);
    } else {
      setState(() {});
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (mounted && !quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await Api.getTreeholeMessages(page: _page);
      final nextMessages = List<Map<String, dynamic>>.from(
        data['messages'] ?? [],
      );
      if (mounted) {
        if (quiet && _sameMessages(_messages, nextMessages) && !_loading) {
          return;
        }
        setState(() {
          _messages = nextMessages;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted && !quiet) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted && !quiet) {
        setState(() {
          _loading = false;
          _error = '树洞加载失败，请重试';
        });
      }
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    _refreshCtrl.forward(from: 0);
    _page = 1;
    await _load();
  }

  Future<void> _post() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() {
      _posting = true;
      _postError = null;
    });
    try {
      await Api.postTreehole(text);
      _msgCtrl.clear();
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('写进树洞了')));
      }
      await _load();
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        setState(() => _postError = e.message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _postError = '留言失败，请稍后重试');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('留言失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _interact(int id, String type) async {
    try {
      final data = await Api.interactTreehole(id, type);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => readInt(m['id']) == id);
        if (idx >= 0) {
          final counts = data['counts'];
          if (counts is Map) {
            _messages[idx]['cloud_hugs'] =
                counts['cloud_hugs'] ?? _messages[idx]['cloud_hugs'];
            _messages[idx]['cloud_coffees'] =
                counts['cloud_coffees'] ?? _messages[idx]['cloud_coffees'];
          }
          final interactions = List<String>.from(
            _messages[idx]['interactions'] ?? [],
          );
          if (!interactions.contains(type)) interactions.add(type);
          _messages[idx]['interactions'] = interactions;
        }
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('互动失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(theme),
            _themeCard(theme),
            Expanded(
              child: _loading
                  ? Center(
                      child: InkWritingLoader(inkColor: theme.gold, size: 40),
                    )
                  : XqRefresh(
                      onRefresh: _refresh,
                      child: _content(theme),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _composer(theme),
      ),
    );
  }

  Widget _header(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '树洞',
                  style: XqTypography.displayMedium.copyWith(
                    color: theme.textPrimary,
                    fontSize: 30,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '匿名写，没人知道是你。',
                  style: XqTypography.bodySmall.copyWith(
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _refreshCtrl,
            builder: (context, child) => Transform.rotate(
              angle: _refreshCtrl.value * 2 * math.pi,
              child: IconButton(
                icon: XqIcon(XqIcons.refresh, color: theme.accentColor, size: 22),
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 今日轻主题：一句宋体引题，不用卡片
  Widget _themeCard(ThemeState theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日一问',
            style: TextStyle(
              color: theme.gold,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dailyPrompt(),
            style: XqTypography.headlineSmall.copyWith(
              color: theme.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 17,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(ThemeState theme) {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        children: [const SizedBox(height: 40), _errorCard(theme)],
      );
    }
    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        children: [
          const SizedBox(height: 56),
          XqEmptyState(
            motif: XqMotif.boat,
            title: '还没有留言',
            subtitle: '还没人写。写一句就行。',
          ),
        ],
    );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _messageCard(_messages[i], theme),
    );
  }

  Widget _errorCard(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        children: [
          XqIcon(XqIcons.alert, color: theme.errorColor),
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: theme.textPrimary)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _messageCard(Map<String, dynamic> message, ThemeState theme) {
    final id = readInt(message['id']);
    final isOwn = message['is_own'] == true;
    final stamp = _displayTime(message['created_at']?.toString());

    // 一张纸条 = 一张卡（L1）里的一段楷体字（内容层）
    return GestureDetector(
      onLongPress: isOwn ? () => _deleteTreehole(id ?? 0) : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: XqDecorations.surface(theme.cardColor, dark: theme.isDark, edge: theme.borderColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isOwn ? '你的纸条' : '匿名',
                style: TextStyle(
                  color: isOwn ? theme.accentColor : theme.textTertiary,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                stamp,
                style: TextStyle(
                  color: theme.gold,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message['content']?.toString() ?? '',
            style: TextStyle(
              fontFamily: XqTypography.content,
              fontFamilyFallback: XqTypography.contentFallback,
              color: theme.textPrimary,
              fontSize: 16,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _interactionChip(
                theme,
                XqIcons.heart,
                readInt(message['cloud_hugs']) ?? 0,
                _hasInteracted(message, 'cloud_hug'),
                id == null
                    ? null
                    : _hasInteracted(message, 'cloud_hug')
                    ? _showAlreadyInteracted
                    : () => _interact(id, 'cloud_hug'),
              ),
              const SizedBox(width: 8),
              _interactionChip(
                theme,
                XqIcons.cup,
                readInt(message['cloud_coffees']) ?? 0,
                _hasInteracted(message, 'cloud_coffee'),
                id == null
                    ? null
                    : _hasInteracted(message, 'cloud_coffee')
                    ? _showAlreadyInteracted
                    : () => _interact(id, 'cloud_coffee'),
              ),
            ],
          ),
          // ── Comments ──
          const SizedBox(height: 6),
          _commentSection(message, theme),
        ],
      ),
    ),
    ); // GestureDetector
  }

  Future<void> _deleteTreehole(int id) async {
    final theme = context.read<ThemeState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('撤回内容', style: TextStyle(color: theme.textPrimary)),
        content: const Text('撤回后找不回来。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: theme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('撤回', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteTreehole(id);
      await _load();
    } catch (_) {
      if (mounted) XqToast.info(context, '撤回失败，请重试');
    }
  }

  Widget _commentSection(Map<String, dynamic> message, ThemeState theme) {
    final msgId = readInt(message['id']);
    if (msgId == null) return const SizedBox.shrink();
    final commentCount = readInt(message['comment_count']) ?? 0;
    final expanded = _commentsExpanded.contains(msgId);
    final loading = _commentsLoading.contains(msgId);
    final comments = _comments[msgId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle button
        InkWell(
          onTap: () => _toggleComments(msgId),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                XqIcon(
                  expanded ? XqIcons.chevronUp : XqIcons.chat,
                  size: 14,
                  color: theme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  commentCount > 0 ? '$commentCount 条回应' : '回应一句',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expanded comments
        if (expanded) ...[
          const SizedBox(height: 8),
          if (loading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 16, height: 16,
                  child: XqInkLoader( color: theme.accentColor),
                ),
              ),
            )
          else ...[
            ...comments.map((c) => _commentItem(c, theme)),
            const SizedBox(height: 8),
            // Comment input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrlFor(msgId),
                    maxLength: 200,
                    style: TextStyle(color: theme.textPrimary, fontSize: 12),
                    cursorColor: theme.accentColor,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '匿名回应一句...',
                      hintStyle: TextStyle(color: theme.textTertiary, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36, height: 36,
                  child: IconButton(
                    icon: _commentPosting.contains(msgId)
                        ? const SizedBox(width: 14, height: 14, child: XqInkLoader())
                        : const XqIcon(XqIcons.send, size: 16),
                    color: theme.accentColor,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: _commentPosting.contains(msgId) ? null : () => _postComment(msgId),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _commentItem(Map<String, dynamic> comment, ThemeState theme) {
    final isOwn = comment['is_own'] == true || comment['is_own'] == 1;
    final content = comment['content']?.toString() ?? '';
    final stamp = _displayTime(comment['created_at']?.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: isOwn ? theme.accentColor.withAlpha(22) : theme.surfaceAlpha,
              borderRadius: BorderRadius.circular(8),
            ),
            child: XqIcon(
              isOwn ? XqIcons.person : XqIcons.eyeOff,
              size: 12,
              color: isOwn ? theme.accentColor : theme.textTertiary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isOwn ? '你' : '匿名'} · $stamp',
                  style: TextStyle(color: theme.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAlreadyInteracted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('送过了'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _toggleComments(int msgId) async {
    if (_commentsExpanded.contains(msgId)) {
      setState(() => _commentsExpanded.remove(msgId));
      return;
    }
    setState(() => _commentsExpanded.add(msgId));
    if (!_comments.containsKey(msgId)) {
      await _loadComments(msgId);
    }
  }

  Future<void> _loadComments(int msgId) async {
    if (_commentsLoading.contains(msgId)) return;
    setState(() => _commentsLoading.add(msgId));
    try {
      final data = await Api.getTreeholeComments(msgId);
      if (mounted) {
        setState(() {
          _comments[msgId] = List<Map<String, dynamic>>.from(data['comments'] ?? []);
          _commentsLoading.remove(msgId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _commentsLoading.remove(msgId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论加载失败'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _postComment(int msgId) async {
    if (_commentPosting.contains(msgId)) return;
    final ctrl = _commentCtrls[msgId];
    if (ctrl == null) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _commentPosting.add(msgId));
    try {
      await Api.postTreeholeComment(msgId, text);
      ctrl.clear();
      HapticFeedback.lightImpact();
      await _loadComments(msgId);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 2)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论失败'), duration: Duration(seconds: 1)),
        );
      }
    } finally {
      if (mounted) setState(() => _commentPosting.remove(msgId));
    }
  }

  TextEditingController _commentCtrlFor(int msgId) {
    return _commentCtrls.putIfAbsent(msgId, () => TextEditingController());
  }

  Widget _interactionChip(
    ThemeState theme,
    XqIcons icon,
    int count,
    bool active,
    VoidCallback? onTap,
  ) {
    final color = active ? theme.accentColor : theme.textTertiary;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            XqIcon(icon, size: 17, color: color),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(ThemeState theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: theme.cardColor.withAlpha(theme.isDark ? 245 : 252),
          border: Border(top: BorderSide(color: theme.borderColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLength: 200,
                    minLines: 1,
                    maxLines: 2,
                    style: TextStyle(color: theme.textPrimary, fontSize: 14),
                    cursorColor: theme.accentColor,
                    decoration: InputDecoration(
                      hintText: '写一句就够了',
                      hintStyle: TextStyle(
                        color: theme.textSecondary.withAlpha(150),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton.filled(
                    icon: _posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: XqInkLoader(),
                          )
                        : const XqIcon(XqIcons.send, size: 18),
                    color: theme.accentColor,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: theme.textTertiary,
                    ),
                    onPressed: _posting || _msgCtrl.text.trim().isEmpty
                        ? null
                        : _post,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _postError ?? '一句就够，写什么都行。',
                    style: TextStyle(
                      color: _postError == null
                          ? theme.textSecondary
                          : theme.errorColor,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  '${_msgCtrl.text.length}/200',
                  style: TextStyle(color: theme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasInteracted(Map<String, dynamic> message, String type) {
    final interactions = message['interactions'];
    return interactions is List && interactions.contains(type);
  }

  bool _sameMessages(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> next,
  ) {
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (readInt(a['id']) != readInt(b['id']) ||
          a['content']?.toString() != b['content']?.toString() ||
          readInt(a['cloud_hugs']) != readInt(b['cloud_hugs']) ||
          readInt(a['cloud_coffees']) != readInt(b['cloud_coffees']) ||
          a['interactions']?.toString() != b['interactions']?.toString()) {
        return false;
      }
    }
    return true;
  }

  String _displayTime(String? raw) => TimeUtils.relative(raw);

  String _dailyPrompt() {
    const prompts = [
      '今天有什么想放下的？',
      '有什么话，不想让认识的人看到？',
      '用一句话说说今天。',
      '今天想谢谢谁？',
      '今天哪个时刻你还记得？',
      '今天的天气，和你的心情像吗？',
      '今天心里在想什么？',
    ];
    return prompts[DateTime.now().weekday % prompts.length];
  }
}
