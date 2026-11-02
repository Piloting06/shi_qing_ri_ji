import 'xq_toast.dart';
import 'city_intro_card.dart';
import '../utils/time_utils.dart';
import '../theme/xq_hand_drawn.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../stores/map_state.dart';
import '../stores/theme_state.dart';

Future<void> _deleteCityComment(int id, BuildContext ctx) async {
  final theme = ctx.read<ThemeState>();
  final ok = await showDialog<bool>(
    context: ctx,
    builder: (c) => AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text('撤回评论', style: TextStyle(color: theme.textPrimary)),
      content: const Text('确定撤回这条评论吗？此操作不可撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text('取消', style: TextStyle(color: theme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('撤回', style: TextStyle(color: Color(0xFFD9706A))),
        ),
      ],
    ),
  );
  if (ok != true || !ctx.mounted) return;
  final success = await ctx.read<MapState>().deleteComment(id);
  if (!success && ctx.mounted) {
    XqToast.error(ctx, '撤回失败，请重试');
  }
}

class CityCommentSheet extends StatelessWidget {
  const CityCommentSheet({super.key});

  static void show(BuildContext context) {
    final map = context.read<MapState>();
    if (map.selectedCity == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CityCommentSheet(),
    ).then((_) {
      // 面板关闭后刷新卡片数据
      map.refreshCards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final map = context.watch<MapState>();
    final theme = context.watch<ThemeState>();
    final city = map.selectedCity;
    if (city == null) return const SizedBox.shrink();

    final mood = map.cityMood(city.code);
    final commentCount = map.cityCommentCount(city.code);
    final moodColor = _moodTint(mood);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withAlpha(230),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final count = map.cityCommentCount(city.code);
                        CityIntroCard.show(
                          context,
                          city,
                          count > 0 ? count : null,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              city.name,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: theme.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: GestureDetector(
                        onTap: () {
                          final count = map.cityCommentCount(city.code);
                          CityIntroCard.show(
                            context,
                            city,
                            count > 0 ? count : null,
                          );
                        },
                        child: Text(
                          '轻触城市名，认识一下这座城市',
                          style: TextStyle(
                            color: theme.textTertiary.withAlpha(130),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    if (mood != null && commentCount >= 5) ...[
                      const SizedBox(height: 8),
                      _moodSummary(mood, theme),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '$commentCount 条足迹',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(
                      height: 8,
                      child: CustomPaint(
                        size: const Size(double.infinity, 8),
                        painter: HandDrawnDividerPainter(
                          inkColor: theme.borderColor,
                          amplitude: 2.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: moodColor?.withAlpha(theme.isDark ? 8 : 5),
                        child: map.comments.isEmpty
                          ? _emptyState(city.name, map.canPost, theme)
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount:
                                  map.comments.length +
                                  (map.commentHasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= map.comments.length) {
                                  map.loadMoreComments();
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                return _commentTile(
                                  map.comments[i],
                                  map,
                                  theme,
                                  context,
                                );
                              },
                            ),
                        ),
                    ),
                    if (map.canPost) _composer(map, theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ); // Padding close
  }

  Widget _moodSummary(String mood, ThemeState theme) {
    final text = switch (mood) {
      'warm' => '最近 7 天，这座城市充满了温暖 💛',
      'sad' => '最近 7 天，这座城市的心情偏忧伤 💙',
      'anxious' => '最近 7 天，大家在这里一起加油 💜',
      'calm' => '最近 7 天，这座城市正在安静地思考 🤍',
      'excited' => '最近 7 天，这里热闹得像过年 🧡',
      _ => '这座城市的心情很复杂，什么都有一些 🌈',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: theme.textPrimary, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _emptyState(String name, bool canPost, ThemeState theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 48, color: theme.borderColor),
            const SizedBox(height: 12),
            Text(
              canPost ? '这是你的城市，说点什么吧' : '还没有人来过，做第一个留下足迹的人吧',
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentTile(
    Map<String, dynamic> c,
    MapState map,
    ThemeState theme,
    BuildContext sheetCtx,
  ) {
    final isOwn = c['is_own'] == true;
    final content = c['content']?.toString() ?? '';
    final likes = c['likes'] as int? ?? 0;
    final liked = c['liked'] == true;
    final stamp = _fmt(c['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOwn)
            Container(
              width: 3,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: theme.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      stamp,
                      style: TextStyle(color: theme.textTertiary, fontSize: 11),
                    ),
                    if (isOwn)
                      GestureDetector(
                        onTap: () =>
                            _deleteCityComment(c['id'] as int, sheetCtx),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: theme.textTertiary.withAlpha(140),
                          ),
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: liked
                          ? null
                          : () => map.likeComment(c['id'] as int),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: liked
                                ? theme.accentColor
                                : theme.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$likes',
                            style: TextStyle(
                              color: liked
                                  ? theme.accentColor
                                  : theme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(MapState map, ThemeState theme) {
    final ctrl = TextEditingController();
    var sending = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(top: BorderSide(color: theme.borderColor)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLength: 100,
                    maxLines: 2,
                    minLines: 1,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '留下你的足迹...',
                      hintStyle: TextStyle(
                        color: theme.textTertiary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: theme.backgroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    icon: sending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    color: theme.accentColor,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.accentColor.withAlpha(20),
                    ),
                    onPressed: sending
                        ? null
                        : () async {
                            final t = ctrl.text.trim();
                            if (t.isEmpty) return;
                            setState(() => sending = true);
                            final r = await map.postComment(t);
                            setState(() => sending = false);
                            if (r.ok) {
                              ctrl.clear();
                            } else {
                              if (context.mounted) {
                                XqToast.error(context, r.message);
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmt(String? iso) => TimeUtils.relative(iso);

  static Color? _moodTint(String? mood) {
    return switch (mood) {
      'warm' => const Color(0xFFF0A830),
      'sad' => const Color(0xFF7B9BB8),
      'anxious' => const Color(0xFFB090C8),
      'calm' => const Color(0xFF78B090),
      'excited' => const Color(0xFFF08848),
      _ => null,
    };
  }
}
