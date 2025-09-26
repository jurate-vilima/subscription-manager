import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

void main() {
  group('Subscription.copyWith sentinel semantics', () {
    test('omitted param keeps old value; explicit null clears it', () {
      final s0 = Subscription(
        id: 's1',
        serviceName: 'Netflix',
        cost: 9.99,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 1, 31),
        billingAnchorDay: 31,
      );

      final s1 = s0.copyWith(
        notes: 'just a note',
      );
      expect(s1.billingAnchorDay, 31);

      final s2 = s1.copyWith(
        billingAnchorDay: null,
      );
      expect(s2.billingAnchorDay, isNull);
    });

    test('can set new anchor day after it was cleared', () {
      final base = Subscription(
        id: 's2',
        serviceName: 'Music',
        cost: 5.00,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 2, 28),
        billingAnchorDay: null,
      );

      final withAnchor = base.copyWith(billingAnchorDay: 28);
      expect(withAnchor.billingAnchorDay, 28);

      final kept = withAnchor.copyWith();
      expect(kept.billingAnchorDay, 28);
    });
  });
}
