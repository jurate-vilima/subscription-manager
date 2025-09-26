import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:subscription_manager/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

class _MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  registerFallbackValue(const NotificationDetails());
  registerFallbackValue(
    tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, 0),
  );
  registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
  registerFallbackValue(const InitializationSettings());
  registerFallbackValue(DateTimeComponents.dateAndTime);

  group('computeTrigger', () {
    test('schedules lead days before renewal at desired time', () {
      final service = NotificationService();
      final today = DateTime.now();
      final baseDate = DateTime(today.year, today.month, today.day)
          .add(const Duration(days: 10));
      final renewal =
          DateTime(baseDate.year, baseDate.month, baseDate.day, 15, 0);

      final trigger = service.computeTrigger(
        renewalLocal: renewal,
        leadDays: 3,
        hour: 8,
        minute: 45,
      );

      final expected = tz.TZDateTime(
              tz.local, baseDate.year, baseDate.month, baseDate.day, 8, 45)
          .subtract(const Duration(days: 3));
      expect(trigger, expected);
    });

    test('shifts to one minute in future when target is past', () {
      final service = NotificationService();
      final pastRenewal = DateTime.now().subtract(const Duration(days: 1));

      final trigger = service.computeTrigger(
        renewalLocal: pastRenewal,
        leadDays: 0,
        hour: pastRenewal.hour,
        minute: pastRenewal.minute,
      );

      final now = tz.TZDateTime.now(tz.local);
      expect(trigger.isAfter(now), isTrue);
      expect(trigger.difference(now).inMinutes <= 2, isTrue);
    });
  });

  group('plugin interactions', () {
    const permissionsChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    final permissionCalls = <MethodCall>[];
    late _MockFlutterLocalNotificationsPlugin plugin;
    late TestDefaultBinaryMessenger messenger;

    setUp(() {
      plugin = _MockFlutterLocalNotificationsPlugin();
      NotificationService().resetForTesting(plugin: plugin);
      permissionCalls.clear();

      when(() => plugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
            onDidReceiveBackgroundNotificationResponse:
                any(named: 'onDidReceiveBackgroundNotificationResponse'),
          )).thenAnswer((_) async => true);
      when(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          )).thenAnswer((_) async {});
      when(() => plugin.cancel(any())).thenAnswer((_) async {});
      when(() => plugin.cancelAll()).thenAnswer((_) async {});

      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        permissionsChannel,
        (call) async {
          permissionCalls.add(call);
          switch (call.method) {
            case 'checkPermissionStatus':
              return 1;
            case 'requestPermissions':
              return <String, int>{'notification': 1};
          }
          return null;
        },
      );
    });

    tearDown(() {
      NotificationService().resetForTesting();
      messenger.setMockMethodCallHandler(permissionsChannel, null);
      clearInteractions(plugin);
    });

    test('scheduleRenewalReminder wires zonedSchedule with expected payload',
        () async {
      final service = NotificationService();
      const uuid = '123e4567-e89b-12d3-a456-426655440001';
      final now = DateTime.now().add(const Duration(days: 2));

      await service.scheduleRenewalReminder(
        subscriptionId: uuid,
        title: 'Reminder',
        body: 'Body',
        renewalDate: now,
        leadDays: 1,
        notifyHour: 10,
        notifyMinute: 15,
      );

      verify(() => plugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
            onDidReceiveBackgroundNotificationResponse:
                any(named: 'onDidReceiveBackgroundNotificationResponse'),
          )).called(1);

      final captured = verify(() => plugin.zonedSchedule(
            captureAny(),
            captureAny(),
            captureAny(),
            captureAny(),
            captureAny(),
            androidScheduleMode: captureAny(named: 'androidScheduleMode'),
            payload: captureAny(named: 'payload'),
            matchDateTimeComponents:
                captureAny(named: 'matchDateTimeComponents'),
          )).captured;

      final id = captured[0] as int;
      final title = captured[1] as String?;
      final body = captured[2] as String?;
      final scheduled = captured[3] as tz.TZDateTime;
      final details = captured[4] as NotificationDetails;
      final mode = captured[5] as AndroidScheduleMode?;
      final payload = captured[6] as String?;
      final matchComponents = captured[7] as DateTimeComponents?;

      final bytes = Uuid.parse(uuid);
      final expectedId =
          (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      final expectedDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 10, 15)
              .subtract(const Duration(days: 1));

      expect(id, expectedId);
      expect(title, 'Reminder');
      expect(body, 'Body');
      expect(scheduled, expectedDate);
      expect(details.android?.channelId, 'renewals_channel');
      expect(mode, AndroidScheduleMode.exactAllowWhileIdle);
      expect(payload, uuid);
      expect(matchComponents, isNull);
    });

    test('cancelForSubscription forwards numeric identifier', () async {
      final service = NotificationService();
      const uuid = '123e4567-e89b-12d3-a456-426614174000';

      await service.cancelForSubscription(uuid);

      final bytes = Uuid.parse(uuid);
      final expectedId =
          (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

      verify(() => plugin.cancel(expectedId)).called(1);
    });

    test('cancelAll forwards to plugin', () async {
      final service = NotificationService();

      await service.cancelAll();

      verify(() => plugin.cancelAll()).called(1);
    });

    test('init is only performed once when scheduling multiple reminders',
        () async {
      final service = NotificationService();
      const firstId = '123e4567-e89b-12d3-a456-4266554400aa';
      const secondId = '123e4567-e89b-12d3-a456-4266554400bb';
      final base = DateTime.now().add(const Duration(days: 3));

      await service.scheduleRenewalReminder(
        subscriptionId: firstId,
        title: 'First',
        body: 'Body',
        renewalDate: base,
        leadDays: 1,
        notifyHour: 9,
        notifyMinute: 0,
      );

      await service.scheduleRenewalReminder(
        subscriptionId: secondId,
        title: 'Second',
        body: 'Body',
        renewalDate: base.add(const Duration(days: 2)),
        leadDays: 1,
        notifyHour: 9,
        notifyMinute: 0,
      );

      verify(() => plugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
            onDidReceiveBackgroundNotificationResponse:
                any(named: 'onDidReceiveBackgroundNotificationResponse'),
          )).called(1);
      verify(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          )).called(2);
    });
  });
}
