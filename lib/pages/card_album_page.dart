import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../widgets/xq_empty_state.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/mood_card/card_album_store.dart';

/// 卡片册：浏览/重分享/删除自己做过的所有心情卡片
class CardAlbumPage extends StatefulWidget {
  const CardAlbumPage({super.key});

  @override
  State<CardAlbumPage> createState() => _CardAlbumPageState();
}

class _CardAlbumPageState extends State<CardAlbumPage> {
  List<CardAlbumEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await CardAlbumStore.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<String> _pathOf(CardAlbumEntry e) => _pathOfPublic(e);

  Future<void> _delete(CardAlbumEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这张卡片？'),
        content: const Text('相册里已保存的图片不受影响，仅从卡片册移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CardAlbumStore.delete(e);
    if (mounted) Navigator.of(context).pop(); // 若在查看页，返回列表
    _load();
  }

  Future<void> _share(CardAlbumEntry e) async {
    try {
      final path = await _pathOf(e);
      if (!File(path).existsSync()) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: '拾晴日记 · ${e.date}',
        ),
      );
    } catch (_) {}
  }

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CardViewer(
          entries: _entries,
          initialIndex: index,
          onDelete: _delete,
          onShare: _share,
        ),
      ),
    );
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
          '卡片册',
          style: XqTypography.headlineLarge.copyWith(color: t.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${_entries.length} 张',
                style: TextStyle(color: t.textSecondary, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _entries.isEmpty
              ? Center(
                  child: XqEmptyState(
                    icon: Icons.style_outlined,
                    title: '卡片册还是空的',
                    subtitle: '在心情页保存或分享卡片后，会自动收进这里',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      return PressableScale(
                        onTap: () => _openViewer(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: t.borderColor.withAlpha(80)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                FutureBuilder<String>(
                                  future: _pathOf(e),
                                  builder: (context, snap) {
                                    final path = snap.data;
                                    if (path == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => ColoredBox(
                                        color: t.surfaceAlpha,
                                        child: const Center(
                                          child:
                                              Icon(Icons.broken_image_outlined),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        8, 16, 8, 6),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black54,
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      e.date,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _CardViewer extends StatefulWidget {
  final List<CardAlbumEntry> entries;
  final int initialIndex;
  final Future<void> Function(CardAlbumEntry) onDelete;
  final Future<void> Function(CardAlbumEntry) onShare;

  const _CardViewer({
    required this.entries,
    required this.initialIndex,
    required this.onDelete,
    required this.onShare,
  });

  @override
  State<_CardViewer> createState() => _CardViewerState();
}

Future<String> _pathOfPublic(CardAlbumEntry e) async {
  final dir = await CardAlbumStore.dir();
  return p.join(dir.path, e.file);
}

class _CardViewerState extends State<_CardViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${_index + 1} / ${widget.entries.length}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.entries.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return FutureBuilder<String>(
            future: _pathOfPublic(widget.entries[i]),
            builder: (context, snap) {
              final path = snap.data;
              if (path == null || !File(path).existsSync()) {
                return const SizedBox.shrink();
              }
              return InteractiveViewer(
                maxScale: 4,
                child: Center(child: Image.file(File(path))),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => widget.onShare(widget.entries[_index]),
              icon: const Icon(Icons.share_rounded,
                  color: Colors.white, size: 18),
              label: const Text('分享', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 20),
            TextButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await widget.onDelete(widget.entries[_index]);
                navigator.pop();
              },
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.withAlpha(200), size: 18),
              label:
                  Text('删除', style: TextStyle(color: Colors.red.withAlpha(200))),
            ),
          ],
        ),
      ),
    );
  }
}
