import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/helpers.dart';
import '../widgets/xq_empty_state.dart';
import '../api/api_client.dart';
import '../constants/mood.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../widgets/ink_writing_loader.dart';
import '../theme/xq_decorations.dart';
import '../widgets/xq_toast.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        Api.getFriendList(),
        Api.getFriendRequests(),
      ]);
      final f = results[0];
      final r = results[1];
      if (mounted) {
        setState(() {
          _friends = _dedupeFriends(
            List<Map<String, dynamic>>.from(f['friends'] ?? []),
          );
          _requests = List<Map<String, dynamic>>.from(r['requests'] ?? []);
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '好友加载失败，请下拉重试';
        });
      }
    }
  }

  List<Map<String, dynamic>> _dedupeFriends(List<Map<String, dynamic>> rows) {
    final byId = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = readInt(row['id']);
      if (id == null) continue;
      byId[id] = row;
    }
    return byId.values.toList();
  }

  bool _isCompletePhone(String value) {
    return RegExp(r'^1\d{10}$').hasMatch(value.trim());
  }

  Future<void> _openAddFriendSheet() async {
    final controller = TextEditingController();
    final theme = context.read<ThemeState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Map<String, dynamic>? result;
        String? error;
        var searching = false;
        var adding = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> search() async {
              final phone = controller.text.trim();
              if (!_isCompletePhone(phone) || searching) return;
              setDialogState(() {
                searching = true;
                result = null;
                error = null;
              });
              try {
                final data = await Api.searchUser(phone);
                if (!ctx.mounted) return;
                final users = data['users'] is List
                    ? List<Map<String, dynamic>>.from(data['users'])
                    : <Map<String, dynamic>>[];
                setDialogState(() {
                  result = users.isEmpty ? null : users.first;
                  error = users.isEmpty ? '没有找到这个手机号' : null;
                  searching = false;
                });
              } on ApiException catch (e) {
                if (e.statusCode == 401) return;
                if (!ctx.mounted) return;
                setDialogState(() {
                  result = null;
                  error = e.message;
                  searching = false;
                });
              } catch (_) {
                if (!ctx.mounted) return;
                setDialogState(() {
                  result = null;
                  error = '查找失败，请稍后重试';
                  searching = false;
                });
              }
            }

            Future<void> add() async {
              final user = result;
              if (user == null || adding) return;
              setDialogState(() => adding = true);
              final success = await _addFriend(user);
              if (!ctx.mounted) return;
              if (success) {
                Navigator.pop(ctx);
                await _load();
              } else {
                setDialogState(() => adding = false);
              }
            }

            final can = _isCompletePhone(controller.text);

            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text(
                '添加友人',
                style: XqTypography.headlineMedium.copyWith(
                  color: theme.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    maxLength: 11,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                    ),
                    cursorColor: theme.accentColor,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '请输入 11 位手机号',
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
                    ),
                    onSubmitted: (_) => can ? search() : null,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: theme.errorColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 12),
                    _searchResult(
                      result!,
                      theme,
                      onAdd: add,
                      adding: adding,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: searching || !can ? null : search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: theme.textOnAccent,
                      disabledBackgroundColor: theme.borderColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: searching
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.textOnAccent,
                            ),
                          )
                        : const Text('查找'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }


  Future<bool> _addFriend(Map<String, dynamic> user) async {
    final phone = user['phone']?.toString() ?? '';
    if (phone.isEmpty) return false;
    try {
      await Api.addFriend(phone);
      if (mounted) {
        HapticFeedback.mediumImpact();
        XqToast.success(context, '申请发出去啦～');
      }
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return false;
      if (mounted) {
        XqToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        XqToast.error(context, '发送失败，请稍后重试');
      }
    }
    return false;
  }

  Future<void> _respond(int id, String status, {bool canView = false}) async {
    try {
      await Api.respondFriend(id, status, canViewMood: canView);
      await _load();
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        XqToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        XqToast.error(context, '处理失败，请稍后重试');
      }
    }
  }

  void _openFriend(Map<String, dynamic> friend) {
    final id = readInt(friend['id']);
    if (id == null) return;
    if (friend['can_view_mood'] != true) {
      XqToast.info(context, '对方暂未开放心情记录');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendMoodPage(friend: friend, friendId: id),
      ),
    );
  }

  Future<void> _openFriendNoteSheet(Map<String, dynamic> friend) async {
    final id = readInt(friend['id']);
    if (id == null) return;
    final name =
        friend['username']?.toString() ?? friend['phone']?.toString() ?? '这位好友';
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var sending = false;
    var focusRequested = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = sheetContext.watch<ThemeState>();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!focusRequested) {
              focusRequested = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (focusNode.canRequestFocus) {
                  focusNode.requestFocus();
                }
              });
            }

            Future<void> send() async {
              final content = controller.text.trim();
              if (content.isEmpty || sending) return;
              setSheetState(() => sending = true);
              try {
                await Api.sendFriendNote(id, content);
                if (!context.mounted) return;
                Navigator.pop(context);
                await _load();
                if (!mounted) return;
                XqToast.success(this.context, '小纸条已经送出啦');
              } on ApiException catch (e) {
                if (e.statusCode == 401) return;
                if (!context.mounted) return;
                setSheetState(() => sending = false);
                XqToast.error(this.context, e.message);
              } catch (_) {
                if (!context.mounted) return;
                setSheetState(() => sending = false);
                XqToast.error(this.context, '纸条发送失败，请稍后重试');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  border: Border(top: BorderSide(color: theme.borderColor)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '留张小纸条',
                              style: XqTypography.headlineMedium.copyWith(
                                color: theme.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: theme.textSecondary),
                          ),
                        ],
                      ),
                      Text(
                        '写给 $name 的一句轻轻的话。',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        maxLength: 80,
                        minLines: 2,
                        maxLines: 4,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 14,
                        ),
                        cursorColor: theme.accentColor,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '写一句想对TA说的话...',
                          hintStyle: TextStyle(
                            color: theme.textSecondary.withAlpha(150),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: sending || controller.text.trim().isEmpty
                              ? null
                              : send,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.accentColor,
                            foregroundColor: theme.textOnAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('送出这张纸条'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    focusNode.dispose();
    controller.dispose();
  }

  Future<void> _confirmDeleteFriend(Map<String, dynamic> friend) async {
    final id = readInt(friend['id']);
    if (id == null) return;
    final name =
        friend['username']?.toString() ?? friend['phone']?.toString() ?? '这位好友';
    final theme = context.read<ThemeState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('删除好友', style: TextStyle(color: theme.textPrimary)),
        content: Text(
          '删除后你们将不能互相查看好友心情，确定删除 $name 吗？',
          style: TextStyle(color: theme.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: theme.errorColor),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Api.deleteFriend(id);
      if (!mounted) return;
      setState(() => _friends.removeWhere((row) => readInt(row['id']) == id));
      HapticFeedback.mediumImpact();
      XqToast.success(context, '已删除好友');
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        XqToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        XqToast.error(context, '删除失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: _loading
            ? Center(child: InkWritingLoader(inkColor: theme.gold, size: 40))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _header(theme),
                    const SizedBox(height: 18),
                    if (_error != null) _errorCard(theme),
                    if (_requests.isNotEmpty) _requestSection(theme),
                    _friendSection(theme),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor.withAlpha(80)),
        boxShadow: XqDecorations.shadowSubtle(dark: theme.isDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '好友',
                  style: XqTypography.headlineLarge.copyWith(
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_friends.length} 位好友 · ${_requests.length} 个待处理请求',
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _openAddFriendSheet,
                  icon: const Icon(Icons.person_add_alt_1, size: 17),
                  label: const Text('添加'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (_requests.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.errorColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_requests.length} 个申请',
                    style: TextStyle(
                      color: theme.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchResult(
    Map<String, dynamic> user,
    ThemeState theme, {
    required VoidCallback onAdd,
    required bool adding,
  }) {
    final relation = readInt(user['relation_status']);
    final direction = user['relation_direction']?.toString();
    final disabled = adding || relation == 0 || relation == 1;
    final label = relation == 1
        ? '已是好友'
        : relation == 0 && direction == 'received'
        ? '去处理申请'
        : relation == 0
        ? '已发送'
        : adding
        ? '发送中'
        : '发送申请';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceAlpha,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        children: [
          _avatar(theme, Icons.person_outline, null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username']?.toString() ??
                      user['phone']?.toString() ??
                      '用户',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user['phone']?.toString() ?? '',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: disabled ? null : onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.accentColor,
              side: BorderSide(
                color: disabled ? theme.borderColor : theme.accentColor,
              ),
              minimumSize: const Size(88, 42),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(ThemeState theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.errorColor.withAlpha(18),
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.errorColor.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: theme.textPrimary, fontSize: 13),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _requestSection(ThemeState theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('好友请求', theme),
        const SizedBox(height: 8),
        ..._requests.map((r) => _requestCard(r, theme)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _requestCard(Map<String, dynamic> request, ThemeState theme) {
    final id = readInt(request['id']);
    final name =
        request['username']?.toString() ??
        request['phone']?.toString() ??
        '新朋友';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(theme, Icons.person_add_alt_1, null),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$name 想加你为好友',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(
                theme,
                '同意并开放心情',
                Icons.favorite_border,
                theme.accentColor,
                id == null ? null : () => _respond(id, '1', canView: true),
              ),
              _actionChip(
                theme,
                '仅同意',
                Icons.check,
                theme.successColor,
                id == null ? null : () => _respond(id, '1'),
              ),
              _actionChip(
                theme,
                '拒绝',
                Icons.close,
                theme.errorColor,
                id == null ? null : () => _respond(id, '-1'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _friendSection(ThemeState theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('${_friends.length} 位好友', theme),
        const SizedBox(height: 10),
        if (_friends.isEmpty)
          XqEmptyState(
            icon: Icons.people_outline,
            title: '还没有好友',
            subtitle: '用手机号添加一个愿意分享心情的人',
            actionLabel: '添加好友',
            onAction: _openAddFriendSheet,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _friends.length,
            itemBuilder: (_, i) => _friendCard(_friends[i], theme),
          ),
      ],
    );
  }

  Widget _friendCard(Map<String, dynamic> friend, ThemeState theme) {
    final name =
        friend['username']?.toString() ?? friend['phone']?.toString() ?? '好友';
    final mood = readInt(friend['latest_mood']);
    final canView = friend['can_view_mood'] == true;
    final note = friend['latest_mood_notes']?.toString().trim() ?? '';
    final latestNote = friend['latest_note']?.toString().trim() ?? '';
    final latestNoteIsMine = friend['latest_note_is_mine'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        onTap: () => _openFriend(friend),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
            border: Border.all(color: theme.borderColor.withAlpha(80)),
            boxShadow: XqDecorations.shadowSubtle(dark: theme.isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: avatar + name + note button + more menu
              Row(
                children: [
                  _avatar(theme, Icons.person_outline, mood),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          canView
                              ? mood == null
                                  ? '还没有心情记录'
                                  : '${moodLabels[mood] ?? '心情'}${note.isEmpty ? '' : ' · $note'}'
                              : '暂未开放心情',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Note button (independent)
                  GestureDetector(
                    onTap: () => _openFriendNoteSheet(friend),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: theme.accentColor.withAlpha(160),
                      ),
                    ),
                  ),
                  // More menu
                  PopupMenuButton<String>(
                    color: theme.cardColor,
                    icon: Icon(Icons.more_horiz, color: theme.textSecondary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onSelected: (value) {
                      final id = readInt(friend['id']);
                      if (id == null) return;
                      if (value == 'view') _openFriend(friend);
                      if (value == 'note') _openFriendNoteSheet(friend);
                      if (value == 'delete') _confirmDeleteFriend(friend);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'view',
                        height: 36,
                        child: Text('查看心情', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 'note',
                        height: 36,
                        child: Text('留张纸条', style: TextStyle(color: theme.accentColor, fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        height: 36,
                        child: Text('删除好友', style: TextStyle(color: theme.errorColor, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
              // Status dot
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: canView ? theme.accentColor : theme.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canView ? '已开放心情' : '未开放',
                    style: TextStyle(
                      color: canView ? theme.accentColor : theme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Latest note (only if exists)
              if (latestNote.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlpha,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${latestNoteIsMine ? '你的纸条' : '对方纸条'} · $latestNote',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _sectionTitle(String text, ThemeState theme) {
    return Text(
      text,
      style: XqTypography.labelLarge.copyWith(color: theme.textSecondary),
    );
  }

  Widget _avatar(ThemeState theme, IconData icon, int? mood) {
    final emoji = mood == null ? null : moodEmojis[mood];
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(22),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: emoji != null
            ? Text(emoji, style: const TextStyle(fontSize: 21))
            : Icon(icon, color: theme.accentColor, size: 22),
      ),
    );
  }

  Widget _actionChip(
    ThemeState theme,
    String label,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(90)),
        minimumSize: const Size(44, 40),
      ),
    );
  }
}

class FriendMoodPage extends StatefulWidget {
  final Map<String, dynamic> friend;
  final int friendId;

  const FriendMoodPage({
    super.key,
    required this.friend,
    required this.friendId,
  });

  @override
  State<FriendMoodPage> createState() => _FriendMoodPageState();
}

class _FriendMoodPageState extends State<FriendMoodPage> {
  final _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _moods = [];
  List<Map<String, dynamic>> _comments = [];
  Map<String, dynamic>? _selectedMood;
  bool _loading = true;
  bool _commentsLoading = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMoods();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMoods() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.getFriendMood(widget.friendId);
      if (!mounted) return;
      final moods = data['moods'] is List
          ? List<Map<String, dynamic>>.from(data['moods'])
          : <Map<String, dynamic>>[];
      setState(() {
        _moods = moods;
        _selectedMood = moods.isEmpty ? null : moods.first;
        _loading = false;
      });
      if (_selectedMood != null) await _loadComments(_selectedMood!);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '心情加载失败，请重试';
        });
      }
    }
  }

  Future<void> _loadComments(Map<String, dynamic> mood) async {
    final moodId = readInt(mood['id']);
    if (moodId == null) return;
    setState(() => _commentsLoading = true);
    try {
      final data = await Api.getMoodComments(moodId);
      if (mounted) {
        setState(() {
          _comments = data['comments'] is List
              ? List<Map<String, dynamic>>.from(data['comments'])
              : [];
          _commentsLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        setState(() => _commentsLoading = false);
        XqToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _commentsLoading = false);
        XqToast.error(context, '评论加载失败，请稍后重试');
      }
    }
  }

  Future<void> _sendComment() async {
    final mood = _selectedMood;
    final moodId = mood == null ? null : readInt(mood['id']);
    final content = _commentCtrl.text.trim();
    if (moodId == null || content.isEmpty || _sending) return;
    if (content.length > 200) {
      XqToast.info(context, '评论最多 200 字');
      return;
    }
    setState(() => _sending = true);
    try {
      await Api.postMoodComment(moodId, content);
      _commentCtrl.clear();
      if (mounted) {
        HapticFeedback.lightImpact();
        await _loadComments(mood!);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        XqToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        XqToast.error(context, '发送失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final name =
        widget.friend['username']?.toString() ??
        widget.friend['phone']?.toString() ??
        '好友';

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: _loading
            ? Center(child: InkWritingLoader(inkColor: theme.gold, size: 40))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: theme.textPrimary,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '$name 的心情',
                          textAlign: TextAlign.center,
                          style: XqTypography.headlineMedium.copyWith(
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    _detailError(theme)
                  else if (_moods.isEmpty)
                    _emptyMood(theme)
                  else ...[
                    ..._moods.map((mood) => _moodCard(mood, theme)),
                    const SizedBox(height: 14),
                    _commentPanel(theme),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _detailError(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        children: [
          Text(_error!, style: TextStyle(color: theme.textPrimary)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadMoods, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _emptyMood(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Text(
        '对方最近还没有心情记录。',
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.textSecondary),
      ),
    );
  }

  Widget _moodCard(Map<String, dynamic> mood, ThemeState theme) {
    final selected = identical(mood, _selectedMood);
    final score = readInt(mood['emotion_type']) ?? 0;
    final note = mood['notes']?.toString().trim() ?? '';
    final date = mood['date']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        onTap: () {
          if (selected) return;
          setState(() => _selectedMood = mood);
          _loadComments(mood);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
            border: Border.all(
              color: selected ? theme.accentColor : theme.borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                moodEmojis[score] ?? '•',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${moodLabels[score] ?? '心情'} · $date',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _commentPanel(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '评论',
            style: XqTypography.labelLarge.copyWith(color: theme.textPrimary),
          ),
          const SizedBox(height: 10),
          if (_commentsLoading)
            LinearProgressIndicator(color: theme.accentColor)
          else if (_comments.isEmpty)
            Text(
              '还没有评论，给对方一点回应吧。',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            )
          else
            ..._comments.map((c) => _commentItem(c, theme)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  maxLength: 200,
                  minLines: 1,
                  maxLines: 3,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '写一句评论...',
                    hintStyle: TextStyle(
                      color: theme.textSecondary.withAlpha(150),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.textOnAccent,
                    minimumSize: const Size(72, 44),
                  ),
                  child: Text(_sending ? '发送中' : '发送'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commentItem(Map<String, dynamic> comment, ThemeState theme) {
    final name =
        comment['username']?.toString() ?? comment['phone']?.toString() ?? '好友';
    final content = comment['content']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.accentColor.withAlpha(24),
            child: Icon(
              Icons.person_outline,
              size: 16,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    height: 1.35,
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

