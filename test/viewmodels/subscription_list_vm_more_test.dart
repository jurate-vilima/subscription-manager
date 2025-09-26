import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/test_doubles.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';

Future<AppLocalizations> _loadL10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Subscription(
      id: 'fallback',
      serviceName: 'Fallback',
      cost: 0,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 1, 1),
    ));
    registerFallbackValue(<Subscription>[]);
  });

  group('SubscriptionListViewModel transitions & sorting', () {
    test('monthly > weekly clears anchor and reschedules notification',
        () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));
      final l10n = await _loadL10n();

      final original = Subscription(
        id: 's1',
        serviceName: 'Netflix',
        cost: 9.99,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 1, 31),
        billingAnchorDay: 31,
      );
      await subsRepo.add(original);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
        nowProvider: () => DateTime(2025, 1, 15),
      );

      await vm.load();
      final baselineReschedules = rescheduler.callCount;

      await vm.update(
        original.copyWith(billingCycle: BillingCycle.weekly),
        l10n,
      );

      final updated = subsRepo.getAll().singleWhere((e) => e.id == 's1');
      expect(updated.billingAnchorDay, isNull);
      verify(() => notif.cancelForSubscription('s1')).called(1);
      verify(() => notif.scheduleRenewalReminder(
            subscriptionId: 's1',
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: updated.nextRenewalDate,
            leadDays: settingsRepo.current.leadDays,
            notifyHour: settingsRepo.current.notifyHour,
            notifyMinute: settingsRepo.current.notifyMinute,
          )).called(1);
      expect(rescheduler.callCount, baselineReschedules);
    });

    test('weekly > monthly sets anchor from nextRenewalDate', () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));
      final l10n = await _loadL10n();

      final original = Subscription(
        id: 's2',
        serviceName: 'Music',
        cost: 5.0,
        currency: 'EUR',
        billingCycle: BillingCycle.weekly,
        nextRenewalDate: DateTime(2025, 2, 28),
      );
      await subsRepo.add(original);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
        nowProvider: () => DateTime(2025, 1, 15),
      );

      await vm.load();
      final baselineReschedules = rescheduler.callCount;

      await vm.update(
        original.copyWith(billingCycle: BillingCycle.monthly),
        l10n,
      );

      final updated = subsRepo.getAll().singleWhere((e) => e.id == 's2');
      expect(updated.billingAnchorDay, 28);
      verify(() => notif.cancelForSubscription('s2')).called(1);
      verify(() => notif.scheduleRenewalReminder(
            subscriptionId: 's2',
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: updated.nextRenewalDate,
            leadDays: settingsRepo.current.leadDays,
            notifyHour: settingsRepo.current.notifyHour,
            notifyMinute: settingsRepo.current.notifyMinute,
          )).called(1);
      expect(rescheduler.callCount, baselineReschedules);
    });

    test('load() rolls overdue items, sorts, and triggers one reschedule',
        () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));

      await subsRepo.addAll([
        Subscription(
          id: 'overdue',
          serviceName: 'Over',
          cost: 1.0,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 2, 28),
          billingAnchorDay: 28,
        ),
        Subscription(
          id: 'today',
          serviceName: 'Today',
          cost: 1.0,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 3, 1),
          billingAnchorDay: 1,
        ),
        Subscription(
          id: 'future',
          serviceName: 'Future',
          cost: 1.0,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 3, 15),
          billingAnchorDay: 15,
        ),
      ]);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
        nowProvider: () => DateTime(2025, 3, 1),
      );

      await vm.load();

      final rolled = subsRepo.getAll();
      expect(rolled.firstWhere((e) => e.id == 'overdue').nextRenewalDate,
          DateTime(2025, 3, 28));
      expect(rolled.firstWhere((e) => e.id == 'today').nextRenewalDate,
          DateTime(2025, 4, 1));
      expect(
          vm.items.map((e) => e.id).toList(), ['future', 'overdue', 'today']);
      expect(rescheduler.callCount, 1);
    });

    test('removeWithMemory + undo restores subscription and notifications',
        () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));
      final l10n = await _loadL10n();

      final toDelete = Subscription(
        id: 's3',
        serviceName: 'Service',
        cost: 2.0,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 2, 10),
        billingAnchorDay: 10,
      );
      await subsRepo.add(toDelete);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
        nowProvider: () => DateTime(2025, 1, 15),
      );
      await vm.load();

      await vm.removeWithMemory('s3');
      verify(() => notif.cancelForSubscription('s3')).called(1);
      expect(subsRepo.getAll(), isEmpty);

      await vm.undoLastDelete(l10n);
      expect(subsRepo.getAll(), hasLength(1));
      verify(() => notif.scheduleRenewalReminder(
            subscriptionId: 's3',
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: any<DateTime>(named: 'renewalDate'),
            leadDays: settingsRepo.current.leadDays,
            notifyHour: settingsRepo.current.notifyHour,
            notifyMinute: settingsRepo.current.notifyMinute,
          )).called(1);
    });
  });

  group('SubscriptionListViewModel operations', () {
    test(
        'add() stores subscription, schedules notification, notifies listeners',
        () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 2, notifyHour: 7, notifyMinute: 45));
      final l10n = await _loadL10n();

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
      );

      var notifications = 0;
      vm.addListener(() => notifications++);

      final nextRenewal = DateTime(2025, 5, 20, 9, 30);

      await vm.add(
        serviceName: 'Prime',
        cost: 12,
        currency: 'EUR',
        cycle: BillingCycle.monthly,
        nextRenewal: nextRenewal,
        category: 'Video',
        notes: 'family',
        url: 'https://prime.example',
        l10n: l10n,
      );

      final stored = subsRepo.getAll().single;
      expect(stored.serviceName, 'Prime');
      expect(stored.billingAnchorDay, nextRenewal.day);
      expect(vm.items.single.id, stored.id);
      expect(notifications, 1);
      verify(() => notif.scheduleRenewalReminder(
            subscriptionId: any<String>(named: 'subscriptionId'),
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: nextRenewal,
            leadDays: settingsRepo.current.leadDays,
            notifyHour: settingsRepo.current.notifyHour,
            notifyMinute: settingsRepo.current.notifyMinute,
          )).called(1);
      expect(rescheduler.callCount, 0);
    });

    test('add() throws when custom cycle has invalid length', () async {
      final notif = MockNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));
      final l10n = await _loadL10n();

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
      );

      expect(
        () => vm.add(
          serviceName: 'Bad custom',
          cost: 9,
          currency: 'EUR',
          cycle: BillingCycle.custom,
          nextRenewal: DateTime(2025, 6, 1),
          customCycleDays: null,
          l10n: l10n,
        ),
        throwsArgumentError,
      );
      expect(subsRepo.getAll(), isEmpty);
      verifyNever(() => notif.scheduleRenewalReminder(
            subscriptionId: any<String>(named: 'subscriptionId'),
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: any<DateTime>(named: 'renewalDate'),
            leadDays: any<int>(named: 'leadDays'),
            notifyHour: any<int>(named: 'notifyHour'),
            notifyMinute: any<int>(named: 'notifyMinute'),
          ));
    });

    test('remove() cancels notification and notifies listeners', () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));

      final existing = Subscription(
        id: 'removable',
        serviceName: 'Service',
        cost: 7.5,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 4, 20),
      );
      await subsRepo.add(existing);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
        nowProvider: () => DateTime(2025, 4, 1),
      );

      var notifications = 0;
      vm.addListener(() => notifications++);

      await vm.load();
      expect(notifications, 1);

      await vm.remove('removable');
      expect(subsRepo.getAll(), isEmpty);
      expect(vm.items, isEmpty);
      expect(notifications, 2);
      verify(() => notif.cancelForSubscription('removable')).called(1);
      verifyNever(() => notif.scheduleRenewalReminder(
            subscriptionId: any<String>(named: 'subscriptionId'),
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: any<DateTime>(named: 'renewalDate'),
            leadDays: any<int>(named: 'leadDays'),
            notifyHour: any<int>(named: 'notifyHour'),
            notifyMinute: any<int>(named: 'notifyMinute'),
          ));
    });

    test('undoLastDelete() is a no-op when history is empty', () async {
      final notif = MockNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));
      final l10n = await _loadL10n();

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
      );

      await vm.undoLastDelete(l10n);
      expect(vm.items, isEmpty);
      expect(subsRepo.getAll(), isEmpty);
      verifyNever(() => notif.scheduleRenewalReminder(
            subscriptionId: any<String>(named: 'subscriptionId'),
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: any<DateTime>(named: 'renewalDate'),
            leadDays: any<int>(named: 'leadDays'),
            notifyHour: any<int>(named: 'notifyHour'),
            notifyMinute: any<int>(named: 'notifyMinute'),
          ));
    });

    test('addFromImport() appends imported subscription and schedules reminder',
        () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));

      final existing = Subscription(
        id: 'existing',
        serviceName: 'Existing',
        cost: 10,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 3, 10),
        billingAnchorDay: 10,
      );
      await subsRepo.add(existing);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
        nowProvider: () => DateTime(2025, 2, 1),
      );

      await vm.load();
      expect(rescheduler.callCount, 1);

      final imported = Subscription(
        id: 'imported',
        serviceName: 'Imported',
        cost: 3,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 2, 20),
        billingAnchorDay: 20,
      );

      await vm.addFromImport(imported);

      expect(subsRepo.getAll(), hasLength(2));
      expect(vm.items.map((e) => e.id), ['imported', 'existing']);
      verify(() => notif.scheduleRenewalReminder(
            subscriptionId: 'imported',
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: imported.nextRenewalDate,
            leadDays: settingsRepo.current.leadDays,
            notifyHour: settingsRepo.current.notifyHour,
            notifyMinute: settingsRepo.current.notifyMinute,
          )).called(1);
      expect(rescheduler.callCount, 1);
    });

    test('replaceAllFromImport() removes old items and schedules new ones',
        () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));

      final oldA = Subscription(
        id: 'oldA',
        serviceName: 'Old A',
        cost: 8,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 4, 5),
        billingAnchorDay: 5,
      );
      final oldB = Subscription(
        id: 'oldB',
        serviceName: 'Old B',
        cost: 6,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 5, 5),
        billingAnchorDay: 5,
      );
      await subsRepo.addAll([oldA, oldB]);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
      );

      await vm.load();
      expect(rescheduler.callCount, 1);

      final newA = Subscription(
        id: 'newA',
        serviceName: 'New A',
        cost: 12,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 2, 1),
        billingAnchorDay: 1,
      );
      final newB = Subscription(
        id: 'newB',
        serviceName: 'New B',
        cost: 11,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 3, 1),
        billingAnchorDay: 1,
      );

      await vm.replaceAllFromImport([newA, newB]);

      expect(subsRepo.getAll().map((s) => s.id).toSet(), {'newA', 'newB'});
      expect(vm.items.map((e) => e.id), ['newA', 'newB']);
      verify(() => notif.cancelForSubscription('oldA')).called(1);
      verify(() => notif.cancelForSubscription('oldB')).called(1);
      verify(() => notif.scheduleRenewalReminder(
            subscriptionId: 'newA',
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: newA.nextRenewalDate,
            leadDays: settingsRepo.current.leadDays,
            notifyHour: settingsRepo.current.notifyHour,
            notifyMinute: settingsRepo.current.notifyMinute,
          )).called(1);
      verify(() => notif.scheduleRenewalReminder(
            subscriptionId: 'newB',
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            renewalDate: newB.nextRenewalDate,
            leadDays: settingsRepo.current.leadDays,
            notifyHour: settingsRepo.current.notifyHour,
            notifyMinute: settingsRepo.current.notifyMinute,
          )).called(1);
      expect(rescheduler.callCount, 1);
    });

    test('removeWithMemory() ignores unknown ids', () async {
      final notif = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
          const AppSettings(leadDays: 3, notifyHour: 9, notifyMinute: 0));
      final l10n = await _loadL10n();

      final existing = Subscription(
        id: 'kept',
        serviceName: 'Keep',
        cost: 2,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 8, 10),
      );
      await subsRepo.add(existing);

      final vm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notif,
        rescheduler: rescheduler.call,
      );
      await vm.load();

      await vm.removeWithMemory('missing');
      await vm.undoLastDelete(l10n);

      expect(subsRepo.getAll(), hasLength(1));
      expect(vm.items.single.id, 'kept');
    });
  });
}
