import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';
import 'api_errors.dart';

class ApiBase {
  static const String baseUrl = 'https://xqrj.glxgo.xin/api';
  static const Duration timeout = Duration(seconds: 15);
  static void Function()? onUnauthorized;
  static void Function()? onAuthenticated;
  static bool _notifyingUnauthorized = false;

  static void resetUnauthorizedFlag() {
    _notifyingUnauthorized = false;
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(StorageKeys.token) ?? '';
      if (t.isNotEmpty) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _handle(http.Response res) async {
    if (res.statusCode == 401) {
      String msg = '登录已过期，请重新登录';
      try {
        final body = json.decode(res.body);
        if (body is Map && body['message'] != null) msg = body['message'];
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.token);
      await prefs.remove(StorageKeys.phone);
      await prefs.remove(StorageKeys.username);
      await prefs.remove(StorageKeys.displayName);
      if (!_notifyingUnauthorized) {
        _notifyingUnauthorized = true;
      }
      onUnauthorized?.call();
      throw ApiException(msg, 401);
    }
    if (res.statusCode >= 400) {
      String msg = '';
      try {
        final body = json.decode(res.body);
        if (body is Map && body['message'] != null) msg = body['message'];
      } catch (_) {}
      throw ApiException(friendlyServerMessage(msg, res.statusCode), res.statusCode);
    }
    if (res.body.isEmpty) return {};
    return Map<String, dynamic>.from(json.decode(res.body));
  }

  /// For modules that need direct access to headers/handle/timeout.
  static Future<Map<String, String>> headers({bool auth = true}) =>
      _headers(auth: auth);

  static Future<Map<String, dynamic>> handle(http.Response res) => _handle(res);
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
