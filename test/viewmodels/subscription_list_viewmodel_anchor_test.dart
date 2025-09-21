import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';
import 'package:subscription_manager/data/subscription_repository.dart';
import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/services/notification_service.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

class MockSubRepo extends Mock implements SubscriptionRepository {}
class MockSettingsRepo extends Mock implements SettingsRepository {}
class MockNotif extends Mock implements NotificationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Subscription(
      id: 'fallback',
      serviceName: 'fallback',
      cost: 0,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2000, 1, 1),
    ));
  });

  test('load() keeps monthly anchor across Feb clamp', () async {
    final subRepo = MockSubRepo();
    final settingsRepo = MockSettingsRepo();
    final notif = MockNotif();

    final jan31 = DateTime(2023, 1, 31, 10, 15);
    final s = Subscription(
      id: 'id-31',
      serviceName: 'A',
      cost: 1,
      currency: 'EUR',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: jan31,
      billingAnchorDay: 31,
    );

    when(() => subRepo.getAll()).thenReturn([s]);
    when(() => subRepo.update(any<Subscription>())).thenAnswer((_) async {});
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
      repo: subRepo,
      settingsRepo: settingsRepo,
      notificationService: notif,
      rescheduler: (_) async {}, 
    );

    await vm.load();

    final updated = vm.items.single;
    expect(updated.nextRenewalDate.isAfter(jan31), isTrue);
    expect(updated.billingAnchorDay, 31);
  });
}
