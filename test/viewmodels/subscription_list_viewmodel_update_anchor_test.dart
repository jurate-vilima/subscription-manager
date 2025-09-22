import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';
import 'package:subscription_manager/data/subscription_repository.dart';
import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/services/notification_service.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';

class MockSubRepo extends Mock implements SubscriptionRepository {}

class MockSettingsRepo extends Mock implements SettingsRepository {}

class MockNotif extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Subscription(
      id: 'x',
      serviceName: 'x',
      cost: 1,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 1, 1),
    ));
  });

  test('update(monthly) sets anchor to nextRenewal.day when no previous anchor',
      () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    final s = Subscription(
      id: 'id1',
      serviceName: 'S',
      cost: 1,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 2, 28, 9, 0),
      billingAnchorDay: null,
    );

    when(() => repo.getAll()).thenReturn([s]);
    when(() => repo.update(any<Subscription>())).thenAnswer((_) async {});
    when(() => settings.current).thenReturn(const AppSettings());
    when(() => notif.cancelForSubscription(any())).thenAnswer((_) async {});
    when(() => notif.scheduleRenewalReminder(
          subscriptionId: any(named: 'subscriptionId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          renewalDate: any(named: 'renewalDate'),
          leadDays: any(named: 'leadDays'),
          notifyHour: any(named: 'notifyHour'),
          notifyMinute: any(named: 'notifyMinute'),
        )).thenAnswer((_) async {});

    final vm = SubscriptionListViewModel(
      repo: repo,
      settingsRepo: settings,
      notificationService: notif,
      rescheduler: (_) async {},
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await vm.load();
    await vm.update(
      s.copyWith(
        nextRenewalDate: DateTime(2025, 2, 28, 9, 0),
        billingCycle: BillingCycle.monthly,
        billingAnchorDay: null,
      ),
      l10n,
    );

    expect(vm.items.single.billingAnchorDay, 28);
  });

  test('update(monthly) preserves existing billingAnchorDay', () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    final s = Subscription(
      id: 'id2',
      serviceName: 'S',
      cost: 1,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 1, 31, 9, 0),
      billingAnchorDay: 31,
    );

    when(() => repo.getAll()).thenReturn([s]);
    when(() => repo.update(any<Subscription>())).thenAnswer((_) async {});
    when(() => settings.current).thenReturn(const AppSettings());
    when(() => notif.cancelForSubscription(any())).thenAnswer((_) async {});
    when(() => notif.scheduleRenewalReminder(
          subscriptionId: any(named: 'subscriptionId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          renewalDate: any(named: 'renewalDate'),
          leadDays: any(named: 'leadDays'),
          notifyHour: any(named: 'notifyHour'),
          notifyMinute: any(named: 'notifyMinute'),
        )).thenAnswer((_) async {});

    final vm = SubscriptionListViewModel(
      repo: repo,
      settingsRepo: settings,
      notificationService: notif,
      rescheduler: (_) async {},
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await vm.load();
    await vm.update(
      s.copyWith(
        nextRenewalDate: DateTime(2025, 2, 28, 9, 0),
        billingCycle: BillingCycle.monthly,
        billingAnchorDay: null,
      ),
      l10n,
    );

    expect(vm.items.single.billingAnchorDay, 31);
  });

  test('daily/weekly/custom -> anchor = null', () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    final s = Subscription(
      id: 'id3',
      serviceName: 'S',
      cost: 1,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 1, 31, 9, 0),
      billingAnchorDay: 31,
    );

    when(() => repo.getAll()).thenReturn([s]);
    when(() => repo.update(any<Subscription>())).thenAnswer((_) async {});
    when(() => settings.current).thenReturn(const AppSettings());
    when(() => notif.cancelForSubscription(any())).thenAnswer((_) async {});
    when(() => notif.scheduleRenewalReminder(
          subscriptionId: any(named: 'subscriptionId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          renewalDate: any(named: 'renewalDate'),
          leadDays: any(named: 'leadDays'),
          notifyHour: any(named: 'notifyHour'),
          notifyMinute: any(named: 'notifyMinute'),
        )).thenAnswer((_) async {});

    final vm = SubscriptionListViewModel(
      repo: repo,
      settingsRepo: settings,
      notificationService: notif,
      rescheduler: (_) async {},
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await vm.load();
    await vm.update(
      s.copyWith(
        billingCycle: BillingCycle.custom,
        nextRenewalDate: s.nextRenewalDate,
        customCycleDays: 10,
      ),
      l10n,
    );

    expect(vm.items.single.billingAnchorDay, isNull);
  });
}
