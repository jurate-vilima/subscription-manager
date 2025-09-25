import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();

  Stream<String> get payloadStream => _payloadController.stream;

  static const String _windowsAppName = 'Subscription Manager';
  static const String _windowsAppUserModelId =
      'com.jurate_vilima.subscription_manager';
  static const String _windowsGuid = 'd2f6e1f3-6a18-4f3c-8f6f-4d3a2aabc123';

  static const String _androidChannelId = 'renewals_channel';
  static const String _androidChannelName = 'Renewal Reminders';
  static const String _androidChannelDescription =
      'Reminders before subscription renewals';

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open');

    const windowsInit = WindowsInitializationSettings(
      appName: _windowsAppName,
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      linux: linuxInit,
      windows: windowsInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          _payloadController.add(payload);
        }
      },
    );

    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  int _idFor(String subscriptionId) {
    final bytes = Uuid.parse(subscriptionId);
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  Future<void> showNowTest() async {
    if (kIsWeb) return;
    await init();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    await _plugin.show(
      9999,
      'Test notification',
      'If you see this, notifications are working.',
      details,
    );
  }

  tz.TZDateTime _computeTrigger({
    required DateTime renewalLocal,
    required int leadDays,
    required int hour,
    required int minute,
  }) {
    final targetAtDesiredTime = tz.TZDateTime.local(
      renewalLocal.year,
      renewalLocal.month,
      renewalLocal.day,
      hour,
      minute,
    ).subtract(Duration(days: leadDays));

    final now = tz.TZDateTime.now(tz.local);
    return targetAtDesiredTime.isBefore(now)
        ? now.add(const Duration(minutes: 1))
        : targetAtDesiredTime;
  }

  @visibleForTesting
  tz.TZDateTime computeTrigger({
    required DateTime renewalLocal,
    required int leadDays,
    required int hour,
    required int minute,
  }) {
    return _computeTrigger(
      renewalLocal: renewalLocal,
      leadDays: leadDays,
      hour: hour,
      minute: minute,
    );
  }

  Future<void> scheduleRenewalReminder({
    required String subscriptionId,
    required String title,
    required String body,
    required DateTime renewalDate,
    int leadDays = 3,
    int notifyHour = 10,
    int notifyMinute = 0,
  }) async {
    if (kIsWeb) return;
    await init();

    final trigger = _computeTrigger(
      renewalLocal: renewalDate.toLocal(),
      leadDays: leadDays,
      hour: notifyHour,
      minute: notifyMinute,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _idFor(subscriptionId),
      title,
      body,
      trigger,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: subscriptionId,
    );
  }

  Future<void> cancelForSubscription(String subscriptionId) async {
    await _plugin.cancel(_idFor(subscriptionId));
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  @visibleForTesting
  void resetForTesting({FlutterLocalNotificationsPlugin? plugin}) {
    _plugin = plugin ?? FlutterLocalNotificationsPlugin();
    _initialized = false;
  }
}
