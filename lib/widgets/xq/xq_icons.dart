import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 素笺自绘线性图标：24 网格、1.5 描边、圆头圆角、单色继承。
/// 覆盖高频动作；其余界面统一 Material outlined 过渡。
enum XqIcons { sunny, heart, compass, person, save, share, trash, close, search, locate, back, more, write, clock }

class XqIcon extends StatelessWidget {
  final XqIcons icon;
  final double size;
  final Color? color;

  const XqIcon(this.icon, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _XqIconPainter(icon, color ?? Theme.of(context).iconTheme.color ?? Colors.black87),
    );
  }
}

class _XqIconPainter extends CustomPainter {
  final XqIcons icon;
  final Color color;
  _XqIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // 网格缩放
    canvas.scale(s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (icon) {
      case XqIcons.sunny: // 太阳：圆 + 8 短芒
        canvas.drawCircle(const Offset(12, 12), 4.2, paint);
        for (int i = 0; i < 8; i++) {
          final a = i * _pi / 4;
          final dir = Offset(mathCos(a), mathSin(a));
          canvas.drawLine(const Offset(12, 12) + dir * 6.4,
              const Offset(12, 12) + dir * 8.6, paint);
        }
      case XqIcons.heart: // 心形（两弧一尖）
        final p = Path()
          ..moveTo(12, 19.5)
          ..cubicTo(6.5, 15.5, 4, 12.5, 4, 9.4)
          ..cubicTo(4, 6.9, 5.9, 5, 8.2, 5)
          ..cubicTo(9.8, 5, 11.2, 5.9, 12, 7.3)
          ..cubicTo(12.8, 5.9, 14.2, 5, 15.8, 5)
          ..cubicTo(18.1, 5, 20, 6.9, 20, 9.4)
          ..cubicTo(20, 12.5, 17.5, 15.5, 12, 19.5)
          ..close();
        canvas.drawPath(p, paint);
      case XqIcons.compass: // 罗盘：圆 + 指针菱形
        canvas.drawCircle(const Offset(12, 12), 9, paint);
        final needle = Path()
          ..moveTo(15.2, 8.8)
          ..lineTo(13.4, 13.4)
          ..lineTo(8.8, 15.2)
          ..lineTo(10.6, 10.6)
          ..close();
        canvas.drawPath(needle, paint);
      case XqIcons.person: // 人：头 + 肩
        canvas.drawCircle(const Offset(12, 8.2), 3.4, paint);
        canvas.drawArc(
          Rect.fromLTWH(5.5, 13.5, 13.0, 9.0), _pi, _pi, false, paint,
        );
      case XqIcons.save: // 下载：竖线箭头 + 托盘
        canvas.drawLine(const Offset(12, 4.5), const Offset(12, 14.5), paint);
        canvas.drawLine(const Offset(8.6, 11.2), const Offset(12, 14.5), paint);
        canvas.drawLine(const Offset(15.4, 11.2), const Offset(12, 14.5), paint);
        final tray = Path()
          ..moveTo(5, 15)
          ..lineTo(5, 19)
          ..lineTo(19, 19)
          ..lineTo(19, 15);
        canvas.drawPath(tray, paint);
      case XqIcons.share: // 分享：托盘 + 上出箭头
        final tray = Path()
          ..moveTo(6, 12)
          ..lineTo(6, 19)
          ..lineTo(18, 19)
          ..lineTo(18, 12);
        canvas.drawPath(tray, paint);
        canvas.drawLine(const Offset(12, 13.5), const Offset(12, 4.5), paint);
        canvas.drawLine(const Offset(8.8, 7.5), const Offset(12, 4.5), paint);
        canvas.drawLine(const Offset(15.2, 7.5), const Offset(12, 4.5), paint);
      case XqIcons.trash: // 垃圾桶
        canvas.drawLine(const Offset(4.5, 6.5), const Offset(19.5, 6.5), paint);
        canvas.drawLine(const Offset(9.5, 6.5), const Offset(9.5, 4.5), paint);
        canvas.drawLine(const Offset(14.5, 6.5), const Offset(14.5, 4.5), paint);
        final body = Path()
          ..moveTo(6, 6.5)
          ..lineTo(6.9, 19.5)
          ..lineTo(17.1, 19.5)
          ..lineTo(18, 6.5);
        canvas.drawPath(body, paint);
        canvas.drawLine(const Offset(10.2, 10), const Offset(10.2, 16), paint);
        canvas.drawLine(const Offset(13.8, 10), const Offset(13.8, 16), paint);
      case XqIcons.close: // 关闭
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), paint);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), paint);
      case XqIcons.search: // 搜索：圆 + 柄
        canvas.drawCircle(const Offset(10.8, 10.8), 6, paint);
        canvas.drawLine(const Offset(15.4, 15.4), const Offset(19.5, 19.5), paint);
      case XqIcons.locate: // 定位：圆 + 十字
        canvas.drawCircle(const Offset(12, 12), 5.6, paint);
        canvas.drawLine(const Offset(12, 3), const Offset(12, 6.5), paint);
        canvas.drawLine(const Offset(12, 17.5), const Offset(12, 21), paint);
        canvas.drawLine(const Offset(3, 12), const Offset(6.5, 12), paint);
        canvas.drawLine(const Offset(17.5, 12), const Offset(21, 12), paint);
      case XqIcons.back: // 返回
        canvas.drawLine(const Offset(14.5, 5.5), const Offset(8, 12), paint);
        canvas.drawLine(const Offset(8, 12), const Offset(14.5, 18.5), paint);
      case XqIcons.more: // 更多：三点
        final dot = Paint()..color = color;
        for (final x in [5.5, 12.0, 18.5]) {
          canvas.drawCircle(Offset(x, 12), 1.4, dot);
        }
      case XqIcons.write: // 笔
        final pen = Path()
          ..moveTo(14.5, 4.8)
          ..lineTo(19.2, 9.5)
          ..lineTo(8.5, 20.2)
          ..lineTo(3.8, 20.2)
          ..lineTo(3.8, 15.5)
          ..close();
        canvas.drawPath(pen, paint);
        canvas.drawLine(const Offset(12.8, 6.5), const Offset(17.5, 11.2), paint);
      case XqIcons.clock: // 时钟
        canvas.drawCircle(const Offset(12, 12), 8.5, paint);
        canvas.drawLine(const Offset(12, 7), const Offset(12, 12), paint);
        canvas.drawLine(const Offset(12, 12), const Offset(15.4, 14), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _XqIconPainter old) => old.icon != icon || old.color != color;
}

// 避免直接依赖 dart:math 前缀污染调用方
const _pi = math.pi;
double mathCos(double x) => math.cos(x);
double mathSin(double x) => math.sin(x);
