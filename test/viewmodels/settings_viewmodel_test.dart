import 'package:flutter_test/flutter_test.dart';

import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import '../support/test_doubles.dart';

class RecordingRescheduler {
  int callCount = 0;
  Iterable<Subscription>? lastInvocation;

  Future<void> call(Iterable<Subscription> items) async {
    callCount++;
    lastInvocation = List<Subscription>.from(items);
  }
}

void main() {
  group('SettingsViewModel', () {
    late FakeSettingsRepository settingsRepo;
    late FakeSubscriptionRepository subscriptionRepo;
    late RecordingRescheduler rescheduler;
    late SettingsViewModel vm;

    setUp(() {
      settingsRepo = FakeSettingsRepository(
        const AppSettings(
          defaultCurrency: 'EUR',
          leadDays: 3,
          themeMode: 'system',
          localeCode: 'en',
          notifyHour: 9,
          notifyMinute: 0,
        ),
      );
      subscriptionRepo = FakeSubscriptionRepository();
      subscriptionRepo.seed([
        Subscription(
          id: 'a',
          serviceName: 'A',
          cost: 9,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 1, 1),
        ),
      ]);
      rescheduler = RecordingRescheduler();
      vm = SettingsViewModel(
        settingsRepo: settingsRepo,
        subscriptionRepo: subscriptionRepo,
        rescheduler: rescheduler.call,
      );
    });

    test('initial state mirrors repository', () {
      expect(vm.state.defaultCurrency, 'EUR');
      expect(vm.state.leadDays, 3);
    });

    test('reload refreshes state and notifies listeners', () async {
      var notifications = 0;
      vm.addListener(() => notifications++);

      await settingsRepo.save(const AppSettings(defaultCurrency: 'USD'));
      vm.reload();

      expect(vm.state.defaultCurrency, 'USD');
      expect(notifications, 1);
    });

    test('update applies valid fields and triggers reschedule when needed',
        () async {
      var notifications = 0;
      vm.addListener(() => notifications++);

      await vm.update(
        defaultCurrency: ' usd ',
        leadDays: 5,
        themeMode: 'dark',
        notifyHour: 8,
        notifyMinute: 45,
        localeCode: 'lv',
      );

      expect(vm.state.defaultCurrency, 'USD');
      expect(vm.state.leadDays, 5);
      expect(vm.state.themeMode, 'dark');
      expect(vm.state.notifyHour, 8);
      expect(vm.state.notifyMinute, 45);
      expect(vm.state.localeCode, 'lv');
      expect(settingsRepo.current, vm.state);
      expect(notifications, 1);
      expect(rescheduler.callCount, 1);
      expect(rescheduler.lastInvocation!.single.id, 'a');
    });

    test('update ignores invalid values and does not reschedule unnecessarily',
        () async {
      rescheduler.callCount = 0;

      final previous = vm.state;
      await vm.update(
        defaultCurrency: 'x',
        leadDays: 99,
        themeMode: 'pink',
        notifyHour: 30,
        notifyMinute: 90,
        localeCode: 'jp',
      );

      expect(vm.state, previous);
      expect(rescheduler.callCount, 0);
    });

    test('setLeadDays validates range and reschedules', () async {
      await vm.setLeadDays(6);
      expect(vm.state.leadDays, 6);
      expect(rescheduler.callCount, 1);

      rescheduler.callCount = 0;
      await vm.setLeadDays(100);
      expect(vm.state.leadDays, 6);
      expect(rescheduler.callCount, 0);
    });

    test('setDefaultCurrency uppercases and validates length', () async {
      await vm.setDefaultCurrency(' gbp ');
      expect(vm.state.defaultCurrency, 'GBP');

      await vm.setDefaultCurrency('zz');
      expect(vm.state.defaultCurrency, 'GBP');
    });

    test('setThemeMode only accepts supported values', () async {
      await vm.setThemeMode('dark');
      expect(vm.state.themeMode, 'dark');

      await vm.setThemeMode('sepia');
      expect(vm.state.themeMode, 'dark');
    });

    test('setLocaleCode only accepts supported codes', () async {
      await vm.setLocaleCode('ru');
      expect(vm.state.localeCode, 'ru');

      await vm.setLocaleCode('jp');
      expect(vm.state.localeCode, 'ru');
    });

    test('setNotifyHour validates and reschedules', () async {
      await vm.setNotifyHour(6);
      expect(vm.state.notifyHour, 6);
      expect(rescheduler.callCount, 1);

      rescheduler.callCount = 0;
      await vm.setNotifyHour(30);
      expect(vm.state.notifyHour, 6);
      expect(rescheduler.callCount, 0);
    });

    test('setNotifyMinute validates and reschedules', () async {
      await vm.setNotifyMinute(15);
      expect(vm.state.notifyMinute, 15);
      expect(rescheduler.callCount, 1);

      rescheduler.callCount = 0;
      await vm.setNotifyMinute(99);
      expect(vm.state.notifyMinute, 15);
      expect(rescheduler.callCount, 0);
    });
  });
}
