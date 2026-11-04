import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xin_qing_ri_ji/api/api_base.dart';
import 'package:xin_qing_ri_ji/api/api_errors.dart';

void main() {
  test('服务器的套话换成人话，写得好的原样保留', () {
    expect(friendlyServerMessage('获取胶囊失败', 400), '胶囊没加载出来，稍后再试');
    expect(friendlyServerMessage('删除失败', 400), '没删掉，稍后再试');
    expect(friendlyServerMessage('', 400), '没成功，稍后再试');
    expect(friendlyServerMessage('验证码错误或已过期', 400), '验证码错误或已过期');
    expect(friendlyServerMessage('这颗胶囊已经封存好了', 409), '这颗胶囊已经封存好了');
  });

  test('按状态码兜底', () {
    expect(friendlyServerMessage('请求失败', 502), '服务器出了点问题，稍后再试');
    expect(friendlyServerMessage('获取树洞失败', 500), '服务器出了点问题，稍后再试');
    expect(friendlyServerMessage('一分钟内只能发一次', 429), '一分钟内只能发一次');
    expect(friendlyServerMessage('', 429), '点得太快了，歇一会儿再试');
  });

  test('网络异常不露英文', () {
    expect(friendlyError(TimeoutException('x')), '等太久了，网络可能不太好');
    expect(friendlyError(const SocketException('Failed host lookup')), '网络不太好，连不上服务器');
    expect(friendlyError(ApiException('邮箱或密码错误', 400)), '邮箱或密码错误');
    expect(friendlyError(StateError('boom')), '出了点问题，稍后再试');
  });
}
