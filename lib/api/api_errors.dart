import 'dart:async';
import 'dart:io';

import 'api_base.dart';

/// 报错说人话：服务器给的「获取X失败 / 删除失败 / 请求失败」和网络异常，统一换成用户看得懂的一句。
/// 服务器已经写得像人话的（「验证码错误或已过期」「这颗胶囊已经封存好了」）原样保留。
String friendlyServerMessage(String raw, int status) {
  final m = raw.trim();
  if (status == 429) return '点得太快了，歇一会儿再试';
  if (status >= 500 && (m.isEmpty || _generic.containsKey(m) || _fetchFailed.hasMatch(m))) {
    return '服务器出了点问题，稍后再试';
  }
  if (m.isEmpty) return '没成功，稍后再试';
  final mapped = _generic[m];
  if (mapped != null) return mapped;
  final fetch = _fetchFailed.firstMatch(m);
  if (fetch != null) return '${fetch.group(1)}没加载出来，稍后再试';
  return m;
}

/// 任意异常 → 一句话（网络断开、超时、证书等不把英文原文露给用户）
String friendlyError(Object e) {
  if (e is ApiException) return e.message;
  if (e is TimeoutException) return '等太久了，网络可能不太好';
  if (e is SocketException || e is HandshakeException) return '网络不太好，连不上服务器';
  final s = e.toString();
  if (s.contains('ClientException') || s.contains('Failed host lookup') || s.contains('Connection')) {
    return '网络不太好，连不上服务器';
  }
  return '出了点问题，稍后再试';
}

final _fetchFailed = RegExp(r'^获取(.{1,8})失败$');

const _generic = {
  '请求失败': '没成功，稍后再试',
  '操作失败': '没成功，稍后再试',
  '获取失败': '没加载出来，稍后再试',
  '删除失败': '没删掉，稍后再试',
  '添加失败': '没加上，稍后再试',
  '发送失败': '没发出去，稍后再试',
  '修改失败': '没改成，稍后再试',
  '评论失败': '评论没发出去，稍后再试',
  '留言失败': '没发出去，稍后再试',
  '绑定失败': '没绑上，稍后再试',
  '签到失败': '没签上，稍后再试',
  '注册失败': '注册没成功，稍后再试',
  '登录失败': '没登上，稍后再试',
  '重置失败': '密码没改成，稍后再试',
  '退出失败': '没退出，稍后再试',
  '纸条发送失败': '纸条没送到，稍后再试',
  '获取天气失败': '天气没加载出来，稍后再试',
};
