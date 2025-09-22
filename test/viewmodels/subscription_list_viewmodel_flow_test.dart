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
import 'package:subscription_manager/utils/rollover.dart';
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

  test('load() rolls past-due to future, updates repo, reschedules all',
      () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    final past = Subscription(
      id: 'p1',
      serviceName: 'Past',
      cost: 5,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2023, 1, 31, 9, 0),
      billingAnchorDay: 31,
    );

    when(() => repo.getAll()).thenReturn([past]);
    Subscription? updatedCaptured;
    when(() => repo.update(any<Subscription>())).thenAnswer((inv) async {
      updatedCaptured = inv.positionalArguments.first as Subscription;
    });
    when(() => settings.current).thenReturn(const AppSettings());

    Iterable<Subscription>? rescheduled;
    final vm = SubscriptionListViewModel(
      repo: repo,
      settingsRepo: settings,
      notificationService: notif,
      rescheduler: (subs) async {
        rescheduled = subs.toList();
      },
    );

    await vm.load();

    expect(vm.items, isNotEmpty);
    expect(updatedCaptured, isNotNull);
    expect(
        updatedCaptured!.nextRenewalDate
            .isAfter(DateTime.now().subtract(const Duration(days: 1))),
        isTrue);
    expect(rescheduled, isNotNull);
    expect(rescheduled!.length, 1);
  });

  test('add() sets anchor for monthly/yearly and schedules notification',
      () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    when(() => repo.add(any<Subscription>())).thenAnswer((_) async {});
    when(() => repo.getAll()).thenReturn([]);
    when(() => settings.current).thenReturn(
        const AppSettings(leadDays: 2, notifyHour: 9, notifyMinute: 30));
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

    await vm.add(
      serviceName: 'S',
      cost: 10,
      currency: 'EUR',
      cycle: BillingCycle.monthly,
      nextRenewal: DateTime(2025, 5, 31, 8, 0),
      l10n: l10n,
    );

    expect(vm.items.single.billingAnchorDay, 31);
    verify(() => notif.scheduleRenewalReminder(
          subscriptionId: any(named: 'subscriptionId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          renewalDate: DateTime(2025, 5, 31, 8, 0),
          leadDays: 2,
          notifyHour: 9,
          notifyMinute: 30,
        )).called(1);
  });

  test('update() cycle transitions adjust anchor and reschedule', () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    final s = Subscription(
      id: 'u1',
      serviceName: 'S',
      cost: 3,
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
        billingCycle: BillingCycle.yearly,
        nextRenewalDate: DateTime(2025, 2, 28, 9, 0),
        billingAnchorDay: null,
      ),
      l10n,
    );
    expect(vm.items.single.billingAnchorDay, 31);

    await vm.update(
      vm.items.single.copyWith(
        billingCycle: BillingCycle.custom,
        nextRenewalDate: vm.items.single.nextRenewalDate,
        customCycleDays: 10,
      ),
      l10n,
    );
    expect(vm.items.single.billingAnchorDay, isNull);

    await vm.update(
      vm.items.single.copyWith(
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 6, 15, 9, 0),
      ),
      l10n,
    );
    expect(vm.items.single.billingAnchorDay, 15);

    verify(() => notif.cancelForSubscription(any()))
        .called(greaterThanOrEqualTo(1));
    verify(() => notif.scheduleRenewalReminder(
          subscriptionId: any(named: 'subscriptionId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          renewalDate: any(named: 'renewalDate'),
          leadDays: any(named: 'leadDays'),
          notifyHour: any(named: 'notifyHour'),
          notifyMinute: any(named: 'notifyMinute'),
        )).called(greaterThanOrEqualTo(1));
  });

  test('remove() and undoLastDelete() manage repo, list and notifications',
      () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    final s = Subscription(
      id: 'r1',
      serviceName: 'S',
      cost: 3,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 1, 31, 9, 0),
      billingAnchorDay: 31,
    );

    when(() => repo.getAll()).thenReturn([s]);
    when(() => repo.update(any<Subscription>())).thenAnswer((_) async {});
    when(() => repo.remove(any())).thenAnswer((_) async {});
    when(() => repo.add(any<Subscription>())).thenAnswer((_) async {});
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
    expect(vm.items.length, 1);

    await vm.removeWithMemory('r1');
    expect(vm.items, isEmpty);
    verify(() => repo.remove('r1')).called(1);
    verify(() => notif.cancelForSubscription('r1')).called(1);

    await vm.undoLastDelete(l10n);
    expect(vm.items.length, 1);
    verify(() => repo.add(any<Subscription>())).called(1);
    verify(() => notif.scheduleRenewalReminder(
          subscriptionId: any(named: 'subscriptionId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          renewalDate: any(named: 'renewalDate'),
          leadDays: any(named: 'leadDays'),
          notifyHour: any(named: 'notifyHour'),
          notifyMinute: any(named: 'notifyMinute'),
        )).called(1);
  });

  test('replaceAllFromImport() removes old, adds new, schedules all', () async {
    final repo = MockSubRepo();
    final settings = MockSettingsRepo();
    final notif = MockNotif();

    final old = Subscription(
      id: 'o1',
      serviceName: 'Old',
      cost: 1,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 1, 31, 9, 0),
      billingAnchorDay: 31,
    );

    final new1 = Subscription(
      id: 'n1',
      serviceName: 'New1',
      cost: 2,
      currency: 'EUR',
      billingCycle: BillingCycle.yearly,
      nextRenewalDate: DateTime(2025, 7, 15, 9, 0),
      billingAnchorDay: 15,
    );

    final new2 = Subscription(
      id: 'n2',
      serviceName: 'New2',
      cost: 3,
      currency: 'EUR',
      billingCycle: BillingCycle.custom,
      nextRenewalDate: DateTime(2025, 3, 10, 9, 0),
      customCycleDays: 10,
      billingAnchorDay: null,
    );

    when(() => repo.getAll()).thenReturn([old]);
    when(() => repo.update(any<Subscription>())).thenAnswer((_) async {});
    when(() => repo.remove(any())).thenAnswer((_) async {});
    when(() => repo.add(any<Subscription>())).thenAnswer((_) async {});
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

    await vm.load();
    await vm.replaceAllFromImport([new1, new2]);

    verify(() => repo.remove('o1')).called(1);
    verify(() => repo.add(any<Subscription>())).called(2);
    verify(() => notif.scheduleRenewalReminder(
          subscriptionId: any(named: 'subscriptionId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          renewalDate: any(named: 'renewalDate'),
          leadDays: any(named: 'leadDays'),
          notifyHour: any(named: 'notifyHour'),
          notifyMinute: any(named: 'notifyMinute'),
        )).called(2);
  });

  test('yearly anchor=29 survives clamp and returns to Feb-29 by 2028',
      () async {
    final s = Subscription(
      id: 'z1',
      serviceName: 'Z',
      cost: 1,
      currency: 'EUR',
      billingCycle: BillingCycle.yearly,
      nextRenewalDate: DateTime(2024, 2, 29, 8, 30),
      billingAnchorDay: 29,
    );
    final y2025 = rollForward(
        start: s.nextRenewalDate,
        cycle: BillingCycle.yearly,
        anchorDay: s.billingAnchorDay,
        now: s.nextRenewalDate);
    final y2026 = rollForward(
        start: y2025, cycle: BillingCycle.yearly, anchorDay: 29, now: y2025);
    final y2027 = rollForward(
        start: y2026, cycle: BillingCycle.yearly, anchorDay: 29, now: y2026);
    final y2028 = rollForward(
        start: y2027, cycle: BillingCycle.yearly, anchorDay: 29, now: y2027);
    expect(y2025, DateTime(2025, 2, 28, 8, 30));
    expect(y2028, DateTime(2028, 2, 29, 8, 30));
  });
}
