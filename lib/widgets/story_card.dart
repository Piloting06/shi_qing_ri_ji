import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'xq/xq_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import 'xq_toast.dart';

/// 素笺故事卡：把一篇故事装帧成可分享的纸卡。
/// 视觉 = 宣纸 + 朱砂小印 + 宋体题 + 楷体文 + 一线墨界。
class StoryCard extends StatelessWidget {
  final String title;
  final String body;
  final String dateText;

  const StoryCard({
    super.key,
    required this.title,
    required this.body,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeState>();
    return Container(
      width: 360,
      height: 480,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: t.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.borderColor, width: 0.6),
      ),
      child: Stack(
        children: [
          // 装裱内衬线（字画裱框意象）
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: t.borderColor.withAlpha(120),
                      width: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '无题' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    fontFamily: 'SerifSC',
                    fontFamilyFallback: ['Noto Serif SC', 'Songti SC'],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 朱砂小印（品牌点睛，本卡唯一）
              Transform.rotate(
                angle: -0.06,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: t.sealColor, width: 1.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '拾',
                    style: TextStyle(
                      color: t.sealColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SerifSC',
                      fontFamilyFallback: ['Songti SC'],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            width: 26,
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 1,
            color: t.textTertiary.withAlpha(90),
          ),
          Expanded(
            child: Text(
              body.isEmpty ? '（还没有写）' : body,
              style: XqTypography.handwrittenBody.copyWith(
                color: t.textPrimary.withAlpha(235),
                fontSize: 14.5,
                height: 1.9,
              ),
              overflow: TextOverflow.fade,
              maxLines: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                dateText,
                style: TextStyle(
                  color: t.textTertiary,
                  fontSize: 10.5,
                  letterSpacing: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                '拾晴日记',
                style: TextStyle(
                  color: t.textTertiary.withAlpha(160),
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
        ),
      ],
      ),
    );
  }
}

/// 故事卡预览页：渲染 + 保存到相册 / 分享
class StoryCardPreviewPage extends StatefulWidget {
  final String title;
  final String body;
  final String dateText;

  const StoryCardPreviewPage({
    super.key,
    required this.title,
    required this.body,
    required this.dateText,
  });

  @override
  State<StoryCardPreviewPage> createState() => _StoryCardPreviewPageState();
}

class _StoryCardPreviewPageState extends State<StoryCardPreviewPage> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception();
      await Gal.putImageBytes(bytes, name: 'shiqing_story_${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) XqToast.success(context, '卡片已保存到相册');
    } on GalException {
      if (mounted) XqToast.error(context, '相册权限未开启或保存失败');
    } catch (_) {
      if (mounted) XqToast.error(context, '保存失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception();
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'shiqing_story_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '素笺 · ${widget.title}\n—— 拾晴日记',
        ),
      );
    } catch (_) {
      if (mounted) XqToast.error(context, '分享失败');
    } finally {
      if (mounted) setState(() => _busy = false);
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
        title: Text(
          '故事卡',
          style: XqTypography.headlineMedium.copyWith(color: t.textPrimary),
        ),
      ),
      body: Stack(
        children: [
          // 窗棂底纹：低透明度细格，如窗下观笺
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LatticePainter(line: t.borderColor),
              ),
            ),
          ),
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RepaintBoundary(
            key: _boundaryKey,
            child: StoryCard(
              title: widget.title,
              body: widget.body,
              dateText: widget.dateText,
            ),
          ),
        ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const XqIcon(XqIcons.save, size: 18),
                    label: const Text('保存到相册'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.accentColor,
                      side: BorderSide(color: t.accentColor.withAlpha(120)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
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
                    onPressed: _busy ? null : _share,
                    icon: const XqIcon(XqIcons.share, size: 18),
                    label: const Text('分享'),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accentColor,
                      foregroundColor: t.textOnAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// 窗棂底纹：极淡细格线（装饰性背景，被卡片大面积遮挡）
class _LatticePainter extends CustomPainter {
  final Color line;
  _LatticePainter({required this.line});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line.withAlpha(60)
      ..strokeWidth = 0.5;
    const cell = 56.0;
    for (double x = 0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LatticePainter old) => old.line != line;
}
