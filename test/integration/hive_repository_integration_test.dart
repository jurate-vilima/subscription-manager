import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/data/subscription_repository.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';

import '../support/hive_test_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hive = HiveTestContext();

  group('Hive repositories', () {
    setUpAll(() async {
      await hive.setUp();
    });

    tearDown(() async {
      await hive.clearBoxes();
    });

    tearDownAll(() async {
      await hive.tearDown();
    });

    test(
      'SettingsRepository returns defaults when Hive is empty',
      () async {
        final repo = SettingsRepository();

        expect(repo.current, const AppSettings());

        final box = Hive.box<AppSettings>('settings');
        expect(box.isEmpty, isTrue);
      },
      tags: ['integration'],
    );

    test(
      'SettingsRepository persists and survives Hive restart',
      () async {
        final repo = SettingsRepository();
        final updated = const AppSettings(
          leadDays: 5,
          defaultCurrency: 'USD',
          themeMode: 'dark',
          notifyHour: 6,
          notifyMinute: 30,
          localeCode: 'en',
        );

        await repo.save(updated);

        expect(repo.current, updated);

        await hive.reopenBoxes();

        final reopenedRepo = SettingsRepository();
        final restored = reopenedRepo.current;
        expect(restored.defaultCurrency, 'USD');
        expect(restored.notifyHour, 6);
        expect(restored.notifyMinute, 30);
        expect(restored.themeMode, 'dark');

        final stored = Hive.box<AppSettings>('settings').get('app');
        expect(stored, isNotNull);
        expect(stored!.defaultCurrency, 'USD');
      },
      tags: ['integration'],
    );

    test(
      'SubscriptionRepository performs CRUD over Hive boxes',
      () async {
        final repo = SubscriptionRepository();
        final initial = Subscription(
          id: 'netflix',
          serviceName: 'Netflix',
          cost: 9.99,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 1, 15),
        );

        await repo.add(initial);

        final afterAdd = repo.getAll();
        expect(afterAdd, hasLength(1));
        expect(afterAdd.single.serviceName, 'Netflix');
        expect(afterAdd.single.billingCycle, BillingCycle.monthly);
        expect(afterAdd.single.cost, 9.99);

        final updated = initial.copyWith(
          serviceName: 'Netflix Premium',
          cost: 15.99,
          billingCycle: BillingCycle.yearly,
          nextRenewalDate: DateTime(2025, 12, 15),
        );

        await repo.update(updated);

        final afterUpdate = repo.getAll();
        expect(afterUpdate, hasLength(1));
        expect(afterUpdate.single.serviceName, 'Netflix Premium');
        expect(afterUpdate.single.billingCycle, BillingCycle.yearly);
        expect(afterUpdate.single.cost, 15.99);
        expect(afterUpdate.single.nextRenewalDate, DateTime(2025, 12, 15));

        await repo.remove(updated.id);
        expect(repo.getAll(), isEmpty);
      },
      tags: ['integration'],
    );

    test(
      'SubscriptionRepository data persists across Hive reopen',
      () async {
        final repo = SubscriptionRepository();
        final spotify = Subscription(
          id: 'spotify',
          serviceName: 'Spotify',
          cost: 12.0,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 6, 1),
        );

        await repo.add(spotify);
        expect(repo.getAll(), hasLength(1));

        await hive.reopenBoxes();

        final afterRestartRepo = SubscriptionRepository();
        final items = afterRestartRepo.getAll();
        expect(items, hasLength(1));
        expect(items.single.serviceName, 'Spotify');
        expect(items.single.billingCycle, BillingCycle.monthly);
      },
      tags: ['integration'],
    );
  });
}
