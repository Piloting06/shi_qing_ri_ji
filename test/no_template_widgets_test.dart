import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 结构守卫（P9 笺谱）：模板组件不许回流。
/// 图标只用自绘 XqIcon；加载只用三点墨 XqInkLoader；下拉刷新只用 XqRefresh。
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  List<String> hits(RegExp pattern, {Set<String> allow = const {}}) => [
        for (final f in files)
          if (!allow.any(f.path.endsWith))
            for (final (i, line) in f.readAsLinesSync().indexed)
              if (!line.trimLeft().startsWith('//') && pattern.hasMatch(line)) '${f.path}:${i + 1}',
      ];

  test('不用 Material 图标', () {
    expect(hits(RegExp(r'(?<![A-Za-z])Icons\.')), isEmpty);
  });

  test('不用系统转圈与进度条', () {
    expect(hits(RegExp(r'(Circular|Linear)ProgressIndicator\(')), isEmpty);
  });

  test('下拉刷新只走 XqRefresh', () {
    expect(hits(RegExp(r'RefreshIndicator\('), allow: {'xq_kit.dart'}), isEmpty);
  });
}
