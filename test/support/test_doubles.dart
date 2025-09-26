import 'package:mocktail/mocktail.dart';

import 'package:subscription_manager/services/notification_service.dart';
import 'package:subscription_manager/data/subscription_repository.dart';
import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

class MockNotificationService extends Mock implements NotificationService {}

class FakeSubscriptionRepository implements SubscriptionRepository {
  final Map<String, Subscription> _store = {};

  @override
  List<Subscription> getAll() => _store.values.toList();

  void seed(Iterable<Subscription> subs) {
    _store
      ..clear()
      ..addEntries(subs.map((s) => MapEntry(s.id, s)));
  }

  Future<void> addAll(Iterable<Subscription> subs) async {
    for (final s in subs) {
      await add(s);
    }
  }

  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> add(Subscription s) async {
    _store[s.id] = s;
  }

  @override
  Future<void> update(Subscription s) async {
    _store[s.id] = s;
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }
}

class FakeSettingsRepository implements SettingsRepository {
  AppSettings _settings;

  FakeSettingsRepository([this._settings = const AppSettings()]);

  @override
  AppSettings get current => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

class RecordingRescheduler {
  int callCount = 0;
  Iterable<Subscription>? lastInvocation;

  Future<void> call(Iterable<Subscription> items) async {
    callCount++;
    lastInvocation = List<Subscription>.from(items);
  }

  void reset() {
    callCount = 0;
    lastInvocation = null;
  }
}

MockNotificationService stubNotificationService() {
  final service = MockNotificationService();
  when(() => service.cancelForSubscription(any())).thenAnswer((_) async {});
  when(() => service.cancelAll()).thenAnswer((_) async {});
  when(() => service.init()).thenAnswer((_) async {});
  when(
    () => service.scheduleRenewalReminder(
      subscriptionId: any(named: 'subscriptionId'),
      title: any(named: 'title'),
      body: any(named: 'body'),
      renewalDate: any(named: 'renewalDate'),
      leadDays: any(named: 'leadDays'),
      notifyHour: any(named: 'notifyHour'),
      notifyMinute: any(named: 'notifyMinute'),
    ),
  ).thenAnswer((_) async {});
  return service;
}

class TestFactory {
  static AppSettings settings({
    int leadDays = 3,
    int notifyHour = 9,
    int notifyMinute = 0,
    String currency = 'EUR',
    String localeCode = 'en',
  }) {
    return AppSettings(
      leadDays: leadDays,
      notifyHour: notifyHour,
      notifyMinute: notifyMinute,
      defaultCurrency: currency,
      localeCode: localeCode,
    );
  }

  static Subscription sub({
    required String id,
    String name = 'Service',
    double cost = 9.99,
    String currency = 'EUR',
    BillingCycle cycle = BillingCycle.monthly,
    required DateTime next,
    int? anchorDay,
    int? customDays,
  }) {
    return Subscription(
      id: id,
      serviceName: name,
      cost: cost,
      currency: currency,
      billingCycle: cycle,
      nextRenewalDate: next,
      billingAnchorDay: anchorDay,
      customCycleDays: customDays,
    );
  }
}
