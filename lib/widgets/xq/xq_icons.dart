import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 自绘线性图标（P9 笺谱）：24 网格、1.5 描边、圆头圆角、单色继承 IconTheme。
/// 全 App 唯一的图标来源；Material Icons 不再直接使用（test/no_template_widgets_test.dart 守住）。
enum XqIcons {
  // 导航与通用
  sunny, heart, heartFill, compass, person, people, personAdd, badge,
  save, share, send, trash, close, check, checkCircle, plus, search, refresh, swap, tune, more,
  back, chevronRight, chevronDown, chevronUp, locate, pin, write,
  // 物
  clock, hourglass, calendar, bell, lock, key, eye, eyeOff, logout, battery, phone, mail,
  info, alert, shield, doc, book, cards, image, folder, code, qr, chat, trend, cup, spark,
  leaf, flame, drop,
  // 天气
  cloud, rain, snow, moon, thermo, wifi,
  // 心情
  faceGood, faceMeh, faceBad,
}

class XqIcon extends StatelessWidget {
  final XqIcons icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const XqIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 22;
    // 与系统 Icon 一致：外层占位 s×s，内层居中，父级强制更大尺寸时图标不被撑大
    final glyph = SizedBox.square(
      dimension: s,
      child: Center(
        child: CustomPaint(
          size: Size.square(s),
          painter: _XqIconPainter(icon, color ?? theme.color ?? const Color(0xFF33302A)),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: glyph);
    return Semantics(label: semanticLabel, child: ExcludeSemantics(child: glyph));
  }
}

class _XqIconPainter extends CustomPainter {
  final XqIcons icon;
  final Color color;
  _XqIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    void line(double x1, double y1, double x2, double y2) => canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);
    void poly(List<double> xy, {bool close = false}) {
      final path = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        path.lineTo(xy[i], xy[i + 1]);
      }
      if (close) path.close();
      canvas.drawPath(path, p);
    }

    void rect(double l, double t, double r, double b, [double radius = 1.5]) =>
        canvas.drawRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)), p);
    void circle(double x, double y, double r) => canvas.drawCircle(Offset(x, y), r, p);
    void dot(double x, double y, [double r = 0.95]) => canvas.drawCircle(Offset(x, y), r, fill);
    void arc(double l, double t, double w, double h, double startDeg, double sweepDeg) =>
        canvas.drawArc(Rect.fromLTWH(l, t, w, h), startDeg * math.pi / 180, sweepDeg * math.pi / 180, false, p);

    Path heartPath() => Path()
      ..moveTo(12, 19.5)
      ..cubicTo(6.5, 15.5, 4, 12.5, 4, 9.4)
      ..cubicTo(4, 6.9, 5.9, 5, 8.2, 5)
      ..cubicTo(9.8, 5, 11.2, 5.9, 12, 7.3)
      ..cubicTo(12.8, 5.9, 14.2, 5, 15.8, 5)
      ..cubicTo(18.1, 5, 20, 6.9, 20, 9.4)
      ..cubicTo(20, 12.5, 17.5, 15.5, 12, 19.5)
      ..close();
    Path cloudPath(double dy) => Path()
      ..moveTo(7.2, 18 + dy)
      ..cubicTo(4.8, 18 + dy, 3.5, 16.3 + dy, 3.5, 14.5 + dy)
      ..cubicTo(3.5, 12.5 + dy, 5.2, 11 + dy, 7.2, 11.2 + dy)
      ..cubicTo(7.8, 8.3 + dy, 10, 6.5 + dy, 12.7, 6.5 + dy)
      ..cubicTo(15.8, 6.5 + dy, 18, 8.8 + dy, 18.2, 11.6 + dy)
      ..cubicTo(19.8, 11.9 + dy, 20.8, 13.3 + dy, 20.8, 14.8 + dy)
      ..cubicTo(20.8, 16.6 + dy, 19.4, 18 + dy, 17.6, 18 + dy)
      ..close();
    void face() {
      circle(12, 12, 8.5);
      dot(9.2, 10.2);
      dot(14.8, 10.2);
    }

    switch (icon) {
      case XqIcons.sunny:
        circle(12, 12, 4.2);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(const Offset(12, 12) + d * 6.4, const Offset(12, 12) + d * 8.6, p);
        }
      case XqIcons.heart:
        canvas.drawPath(heartPath(), p);
      case XqIcons.heartFill:
        canvas.drawPath(heartPath(), fill);
      case XqIcons.compass:
        circle(12, 12, 9);
        poly([15.2, 8.8, 13.4, 13.4, 8.8, 15.2, 10.6, 10.6], close: true);
      case XqIcons.person:
        circle(12, 8.2, 3.4);
        arc(5.5, 13.5, 13, 9, 180, 180);
      case XqIcons.people:
        circle(9, 8.5, 3);
        arc(3.2, 13.5, 11.6, 8, 180, 180);
        circle(16.6, 9.2, 2.4);
        arc(14.2, 14.2, 7.4, 6, 200, 140);
      case XqIcons.personAdd:
        circle(9.5, 8.2, 3.4);
        arc(3, 13.5, 13, 9, 180, 180);
        line(18.5, 6.5, 18.5, 11.5);
        line(16, 9, 21, 9);
      case XqIcons.badge:
        rect(3.5, 6, 20.5, 18);
        circle(9, 10.8, 2);
        arc(5.6, 13.6, 6.8, 5, 180, 180);
        line(14, 10.5, 18, 10.5);
        line(14, 14, 17, 14);
      case XqIcons.save:
        line(12, 4.5, 12, 14.5);
        poly([8.6, 11.2, 12, 14.5, 15.4, 11.2]);
        poly([5, 15, 5, 19, 19, 19, 19, 15]);
      case XqIcons.share:
        poly([6, 12, 6, 19, 18, 19, 18, 12]);
        line(12, 13.5, 12, 4.5);
        poly([8.8, 7.5, 12, 4.5, 15.2, 7.5]);
      case XqIcons.send:
        poly([3.5, 11.2, 20.5, 4, 13.2, 20.5, 10.8, 13.2], close: true);
        line(10.8, 13.2, 20.5, 4);
      case XqIcons.trash:
        line(4.5, 6.5, 19.5, 6.5);
        poly([9.5, 6.5, 9.5, 4.5, 14.5, 4.5, 14.5, 6.5]);
        poly([6, 6.5, 6.9, 19.5, 17.1, 19.5, 18, 6.5]);
        line(10.2, 10, 10.2, 16);
        line(13.8, 10, 13.8, 16);
      case XqIcons.close:
        line(6, 6, 18, 18);
        line(18, 6, 6, 18);
      case XqIcons.check:
        poly([5, 12.5, 10, 17, 19, 7.5]);
      case XqIcons.checkCircle:
        circle(12, 12, 8.5);
        poly([8, 12.3, 10.8, 15, 16, 9.5]);
      case XqIcons.plus:
        line(12, 5, 12, 19);
        line(5, 12, 19, 12);
      case XqIcons.search:
        circle(10.8, 10.8, 6);
        line(15.4, 15.4, 19.5, 19.5);
      case XqIcons.refresh:
        arc(5, 5, 14, 14, 330, -290);
        poly([15.8, 4.6, 18.8, 8.2, 14.8, 9.4]);
      case XqIcons.swap:
        line(5, 9, 19, 9);
        poly([15.5, 5.5, 19, 9, 15.5, 12.5]);
        line(19, 15, 5, 15);
        poly([8.5, 11.5, 5, 15, 8.5, 18.5]);
      case XqIcons.tune:
        line(4, 7, 20, 7);
        line(4, 12, 20, 12);
        line(4, 17, 20, 17);
        dot(9, 7, 2);
        dot(15, 12, 2);
        dot(7.5, 17, 2);
      case XqIcons.more:
        for (final x in [5.5, 12.0, 18.5]) {
          dot(x, 12, 1.4);
        }
      case XqIcons.back:
        poly([14.5, 5.5, 8, 12, 14.5, 18.5]);
      case XqIcons.chevronRight:
        poly([9.5, 5.5, 16, 12, 9.5, 18.5]);
      case XqIcons.chevronDown:
        poly([5.5, 9.5, 12, 16, 18.5, 9.5]);
      case XqIcons.chevronUp:
        poly([5.5, 14.5, 12, 8, 18.5, 14.5]);
      case XqIcons.locate:
        circle(12, 12, 5.6);
        line(12, 3, 12, 6.5);
        line(12, 17.5, 12, 21);
        line(3, 12, 6.5, 12);
        line(17.5, 12, 21, 12);
      case XqIcons.pin:
        canvas.drawPath(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(8, 16.5, 5.5, 13.2, 5.5, 10)
            ..arcToPoint(const Offset(18.5, 10), radius: const Radius.circular(6.5))
            ..cubicTo(18.5, 13.2, 16, 16.5, 12, 21)
            ..close(),
          p,
        );
        circle(12, 10, 2.3);
      case XqIcons.write:
        poly([14.5, 4.8, 19.2, 9.5, 8.5, 20.2, 3.8, 20.2, 3.8, 15.5], close: true);
        line(12.8, 6.5, 17.5, 11.2);
      case XqIcons.clock:
        circle(12, 12, 8.5);
        poly([12, 7, 12, 12, 15.4, 14]);
      case XqIcons.hourglass:
        line(6.5, 4, 17.5, 4);
        line(6.5, 20, 17.5, 20);
        canvas.drawPath(
          Path()
            ..moveTo(8, 4)
            ..cubicTo(8, 9, 12, 10, 12, 12)
            ..cubicTo(12, 14, 8, 15, 8, 20)
            ..moveTo(16, 4)
            ..cubicTo(16, 9, 12, 10, 12, 12)
            ..cubicTo(12, 14, 16, 15, 16, 20),
          p,
        );
      case XqIcons.calendar:
        rect(4.5, 6, 19.5, 19.5);
        line(4.5, 10, 19.5, 10);
        line(8.5, 4, 8.5, 7.5);
        line(15.5, 4, 15.5, 7.5);
      case XqIcons.bell:
        canvas.drawPath(
          Path()
            ..moveTo(6, 16.5)
            ..lineTo(18, 16.5)
            ..moveTo(7.5, 16.5)
            ..lineTo(7.5, 11)
            ..arcToPoint(const Offset(16.5, 11), radius: const Radius.circular(4.5))
            ..lineTo(16.5, 16.5),
          p,
        );
        line(10.5, 19.3, 13.5, 19.3);
      case XqIcons.lock:
        rect(6, 11, 18, 20);
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 11)
            ..lineTo(8.5, 8)
            ..arcToPoint(const Offset(15.5, 8), radius: const Radius.circular(3.5))
            ..lineTo(15.5, 11),
          p,
        );
        line(12, 14.5, 12, 16.5);
      case XqIcons.key:
        circle(8, 12, 3.5);
        line(11.5, 12, 20, 12);
        line(17, 12, 17, 15);
        line(19.5, 12, 19.5, 14.5);
      case XqIcons.eye:
      case XqIcons.eyeOff:
        canvas.drawPath(
          Path()
            ..moveTo(3, 12)
            ..quadraticBezierTo(12, 4, 21, 12)
            ..quadraticBezierTo(12, 20, 3, 12),
          p,
        );
        circle(12, 12, 2.8);
        if (icon == XqIcons.eyeOff) line(4.5, 4.5, 19.5, 19.5);
      case XqIcons.logout:
        poly([13, 4.5, 6, 4.5, 6, 19.5, 13, 19.5]);
        line(10.5, 12, 20, 12);
        poly([16.5, 8.5, 20, 12, 16.5, 15.5]);
      case XqIcons.battery:
        rect(3.5, 8, 18.5, 16);
        line(20.5, 10.5, 20.5, 13.5);
        poly([12, 9.8, 9.8, 12.4, 12.4, 11.8, 10.4, 14.4]);
      case XqIcons.phone:
        rect(7.5, 3.5, 16.5, 20.5, 2);
        line(11, 17.5, 13, 17.5);
      case XqIcons.mail:
        rect(4, 6.5, 20, 17.5);
        poly([4.5, 7.5, 12, 13, 19.5, 7.5]);
      case XqIcons.info:
        circle(12, 12, 8.5);
        line(12, 11, 12, 16.5);
        dot(12, 7.9);
      case XqIcons.alert:
        circle(12, 12, 8.5);
        line(12, 7.5, 12, 13);
        dot(12, 16.2);
      case XqIcons.shield:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.5)
            ..lineTo(19, 6.5)
            ..lineTo(19, 11.5)
            ..cubicTo(19, 16, 16, 19, 12, 20.5)
            ..cubicTo(8, 19, 5, 16, 5, 11.5)
            ..lineTo(5, 6.5)
            ..close(),
          p,
        );
        poly([9, 12, 11.2, 14.2, 15.2, 10]);
      case XqIcons.doc:
        poly([6, 3.5, 14.5, 3.5, 18.5, 7.5, 18.5, 20.5, 6, 20.5], close: true);
        poly([14.5, 3.5, 14.5, 7.5, 18.5, 7.5]);
        line(9, 12, 15.5, 12);
        line(9, 15.5, 15.5, 15.5);
      case XqIcons.book:
        canvas.drawPath(
          Path()
            ..moveTo(12, 7)
            ..cubicTo(9.5, 5.3, 6.5, 5, 4, 5.5)
            ..lineTo(4, 18.5)
            ..cubicTo(6.5, 18, 9.5, 18.3, 12, 20)
            ..cubicTo(14.5, 18.3, 17.5, 18, 20, 18.5)
            ..lineTo(20, 5.5)
            ..cubicTo(17.5, 5, 14.5, 5.3, 12, 7)
            ..lineTo(12, 20),
          p,
        );
      case XqIcons.cards:
        rect(4.5, 8, 15.5, 20);
        poly([8, 8, 8, 4.5, 19.5, 4.5, 19.5, 16.5, 15.5, 16.5]);
      case XqIcons.image:
        rect(4, 5.5, 20, 18.5);
        poly([4.5, 16.5, 9.5, 11.5, 13, 15, 15.5, 12.5, 19.5, 16.5]);
        circle(15.5, 9, 1.3);
      case XqIcons.folder:
        poly([3.5, 6, 9.5, 6, 11.5, 8.5, 20.5, 8.5, 20.5, 18.5, 3.5, 18.5], close: true);
      case XqIcons.code:
        poly([8.5, 7.5, 4, 12, 8.5, 16.5]);
        poly([15.5, 7.5, 20, 12, 15.5, 16.5]);
      case XqIcons.qr:
        rect(4, 4, 10, 10, 1);
        rect(14, 4, 20, 10, 1);
        rect(4, 14, 10, 20, 1);
        dot(7, 7, 1.1);
        dot(17, 7, 1.1);
        dot(7, 17, 1.1);
        dot(15, 15, 1.1);
        dot(19, 15, 1.1);
        dot(17, 17, 1.1);
        dot(15, 19, 1.1);
        dot(19, 19, 1.1);
      case XqIcons.chat:
        canvas.drawPath(
          Path()
            ..addRRect(RRect.fromLTRBR(4, 5, 20, 16, const Radius.circular(3)))
            ..moveTo(8.5, 16)
            ..lineTo(7.5, 20)
            ..lineTo(12.5, 16),
          p,
        );
      case XqIcons.trend:
        poly([4, 17, 9.5, 11.5, 13, 14.5, 20, 7.5]);
        poly([15.5, 7.5, 20, 7.5, 20, 12]);
      case XqIcons.cup:
        poly([5, 9, 5, 15.5, 6, 18.5, 8, 19.5, 13, 19.5, 15, 18.5, 16, 15.5, 16, 9], close: true);
        arc(14, 10.5, 5.5, 5, -90, 180);
        line(8.5, 4.5, 8.5, 6.5);
        line(12, 4.5, 12, 6.5);
      case XqIcons.spark:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.5)
            ..quadraticBezierTo(12.8, 11.2, 20.5, 12)
            ..quadraticBezierTo(12.8, 12.8, 12, 20.5)
            ..quadraticBezierTo(11.2, 12.8, 3.5, 12)
            ..quadraticBezierTo(11.2, 11.2, 12, 3.5)
            ..close(),
          p,
        );
      case XqIcons.leaf:
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 18.5)
            ..cubicTo(5.5, 10.5, 10.5, 5.5, 18.5, 5.5)
            ..cubicTo(18.5, 13.5, 13.5, 18.5, 5.5, 18.5)
            ..close(),
          p,
        );
        line(5.5, 18.5, 13.5, 10.5);
      case XqIcons.flame:
        canvas.drawPath(
          Path()
            ..moveTo(12, 20.5)
            ..cubicTo(8, 20.5, 6, 17.8, 6, 14.8)
            ..cubicTo(6, 11, 9.5, 9.5, 10, 4.5)
            ..cubicTo(13.5, 7, 18, 10, 18, 14.8)
            ..cubicTo(18, 17.8, 16, 20.5, 12, 20.5)
            ..close()
            ..moveTo(12, 20.5)
            ..cubicTo(10.3, 20.5, 9.6, 19.1, 9.6, 17.9)
            ..cubicTo(9.6, 16.2, 11.2, 15.3, 12, 13.8)
            ..cubicTo(12.8, 15.3, 14.4, 16.2, 14.4, 17.9)
            ..cubicTo(14.4, 19.1, 13.7, 20.5, 12, 20.5),
          p,
        );
      case XqIcons.drop:
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..cubicTo(15, 8, 17.5, 11, 17.5, 14.5)
            ..arcToPoint(const Offset(6.5, 14.5), radius: const Radius.circular(5.5))
            ..cubicTo(6.5, 11, 9, 8, 12, 4)
            ..close(),
          p,
        );
      case XqIcons.cloud:
        canvas.drawPath(cloudPath(0), p);
      case XqIcons.rain:
        canvas.drawPath(cloudPath(-3.5), p);
        line(8.5, 17.5, 7.5, 20);
        line(12.5, 17.5, 11.5, 20);
        line(16.5, 17.5, 15.5, 20);
      case XqIcons.snow:
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3 + math.pi / 2;
          final d = Offset(math.cos(a), math.sin(a)) * 8;
          canvas.drawLine(const Offset(12, 12) - d, const Offset(12, 12) + d, p);
        }
      case XqIcons.moon:
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: const Offset(11.5, 12.5), radius: 7.5)),
            Path()..addOval(Rect.fromCircle(center: const Offset(15.5, 9), radius: 6.2)),
          ),
          p,
        );
      case XqIcons.thermo:
        canvas.drawPath(
          Path()
            ..moveTo(10, 14.2)
            ..lineTo(10, 5.5)
            ..arcToPoint(const Offset(14, 5.5), radius: const Radius.circular(2))
            ..lineTo(14, 14.2)
            ..arcToPoint(const Offset(10, 14.2), radius: const Radius.circular(3.8), largeArc: true),
          p,
        );
        line(12, 9, 12, 16);
      case XqIcons.wifi:
        for (final r in [3.2, 6.6, 10.0]) {
          arc(12 - r, 18.5 - r, r * 2, r * 2, -135, 90);
        }
        dot(12, 18.5, 1.1);
      case XqIcons.faceGood:
        face();
        arc(8.5, 10.5, 7, 5.5, 20, 140);
      case XqIcons.faceMeh:
        face();
        line(9, 15.2, 15, 15.2);
      case XqIcons.faceBad:
        face();
        arc(8.5, 14.3, 7, 5.5, 200, 140);
    }
  }

  @override
  bool shouldRepaint(covariant _XqIconPainter old) => old.icon != icon || old.color != color;
}
