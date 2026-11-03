import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../constants/keys.dart';
import '../pages/capsule_page.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  NotificationService.persistPendingPayload(payload);
}

class NotificationService {
  static bool _initialized = false;
  static Future<void>? _initializing;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void bindNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<void> initialize() {
    if (_initialized) return Future.value();
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;
    return _initializing = _doInitialize();
  }

  static Future<void> _doInitialize() async {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      final launchDetails = await _notifications
          .getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if (launchPayload != null && launchPayload.isNotEmpty) {
        await persistPendingPayload(launchPayload);
      }

      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  static Future<bool> requestPermissionIfNeeded() async {
    await initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return androidGranted ?? iosGranted ?? true;
  }

  /// Returns true if the reminder was scheduled successfully
  static Future<bool> scheduleCapsuleReminder({
    required int capsuleId,
    required String openDate,
    required String preview,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(StorageKeys.capsuleNotify) ?? true;
      if (!enabled) return false;

      await initialize();

      // Check if notifications are actually enabled at system level (Android 13+)
      final android = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final systemEnabled = await android?.areNotificationsEnabled();
      if (systemEnabled == false) return false;

      final localDate = DateTime.tryParse(openDate);
      if (localDate == null) return false;

      final trigger = tz.TZDateTime(
        tz.local,
        localDate.year,
        localDate.month,
        localDate.day,
        9,
        8,
      );

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'capsule_reminders',
          '时光胶囊提醒',
          channelDescription: '胶囊到期时提醒你',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            preview,
            contentTitle: '有一颗胶囊到期了',
            summaryText: '到了约好的日子，可以打开了。',
          ),
        ),
        iOS: const DarwinNotificationDetails(),
      );

      // Android 14+ 精准闹钟可能被用户关闭，降级为非精准（仍会提醒，可能偏差几分钟）
      var mode = AndroidScheduleMode.exactAllowWhileIdle;
      final canExact = await android?.canScheduleExactNotifications();
      if (canExact == false) {
        mode = AndroidScheduleMode.inexactAllowWhileIdle;
      }

      await _notifications.zonedSchedule(
        700000 + capsuleId,
        '有一颗胶囊到期了',
        preview,
        trigger,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': 'capsule', 'capsuleId': capsuleId}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelCapsuleReminder(int capsuleId) async {
    try {
      await initialize();
      await _notifications.cancel(700000 + capsuleId);
    } catch (_) {}
  }

  static Future<void> openPendingCapsuleIfAny(
    GlobalKey<NavigatorState> navKey,
  ) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.pendingCapsuleLaunch);
    if (raw == null || raw.isEmpty) return;
    final capsuleId = _capsuleIdFromPayload(raw);
    if (capsuleId == null) {
      await prefs.remove(StorageKeys.pendingCapsuleLaunch);
      return;
    }

    await prefs.remove(StorageKeys.pendingCapsuleLaunch);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    final nav = navKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => CapsulePage(initialCapsuleId: capsuleId),
      ),
    );
  }

  static Future<void> persistPendingPayload(String payload) async {
    final capsuleId = _capsuleIdFromPayload(payload);
    if (capsuleId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.pendingCapsuleLaunch, payload);
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    persistPendingPayload(payload).then((_) {
      final key = _navigatorKey;
      if (key != null) {
        openPendingCapsuleIfAny(key);
      }
    });
  }

  /// 检查系统通知是否已开启
  static Future<bool> areSystemNotificationsEnabled() async {
    await initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await android?.areNotificationsEnabled();
    return enabled ?? true; // 非Android系统默认true
  }

  /// 快速测试通知 — 1分钟后推送，用于验证通知功能
  static Future<String?> scheduleQuickTest() async {
    await initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final systemEnabled = await android?.areNotificationsEnabled();
    if (systemEnabled != true) {
      // 尝试请求权限
      final granted = await android?.requestNotificationsPermission();
      if (granted != true) return '系统通知未开启';
    }

    final now = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    var testMode = AndroidScheduleMode.exactAllowWhileIdle;
    final canExact = await android?.canScheduleExactNotifications();
    if (canExact == false) {
      testMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }
    await _notifications.zonedSchedule(
      999999,
      '测试胶囊提醒',
      '通知正常。胶囊到期时会这样提醒你。',
      now,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'capsule_reminders',
          '时光胶囊提醒',
          channelDescription: '胶囊到期时提醒你',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: testMode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    return null; // success
  }

  static int? _capsuleIdFromPayload(String payload) {
    try {
      final map = jsonDecode(payload);
      if (map is! Map) return null;
      final type = map['type']?.toString();
      if (type != 'capsule') return null;
      final value = map['capsuleId'];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    } catch (_) {}
    return null;
  }
}
