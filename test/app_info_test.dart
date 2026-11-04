import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/constants/app_info.dart';

void main() {
  test('关于页版本号与 pubspec 一致（防止再次写死漂移）', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([\d.]+)\+', multiLine: true).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec.yaml 缺 version 行');
    expect(appVersion, m!.group(1));
  });
}
