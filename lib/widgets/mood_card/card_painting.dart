import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../weather_sky.dart';
import '../xq/xq_paper.dart';

/// 卡上的一小幅笺头画（册页、邮票用）：静态天色 + 云 + 三重山 + 雨雪 + 点景，不动。
class CardPainting extends StatelessWidget {
  const CardPainting({super.key, required this.condition, required this.paper, this.seed = 7, this.motif = true});
  final SkyCondition condition;
  final Color paper;
  final int seed;
  final bool motif;

  @override
  Widget build(BuildContext context) {
    final palette = SkyPalette.of(condition, SkyTime.day);
    return ValueListenableBuilder<ui.Image?>(
      valueListenable: XqPaper.image,
      builder: (context, grain, _) => FutureBuilder<ui.Image>(
        future: motif ? XqPaper.loadImage(skyMotifFor(condition)) : null,
        builder: (context, snap) => CustomPaint(
          painter: WeatherSkyPainter(
            palette: palette,
            condition: condition,
            paper: paper,
            seed: seed,
            layers: const {SkyLayer.sky, SkyLayer.clouds, SkyLayer.mountains, SkyLayer.precip},
            grain: grain,
            motif: snap.data,
            orbAt: const Offset(0.72, 0.24),
            motifAt: const Offset(0.32, 0.8),
            motifWidth: 0.26,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
