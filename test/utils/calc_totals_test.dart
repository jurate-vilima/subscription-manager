import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/utils/calc.dart';

void main() {
  const eps = 1e-9;

  group('calc totals', () {
    test('mixed cycles aggregate correctly', () {
      // Keep constants in sync with calc.dart to avoid drift.
      const weeksPerYear = daysPerYear / 7.0;
      const weeksPerMonth = weeksPerYear / monthsPerYear;
      const daysPerMonthLocal = daysPerYear / monthsPerYear;

      final items = [
        Subscription(
          id: 'm',
          serviceName: 'M',
          cost: 10,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 1, 1),
        ),
        Subscription(
          id: 'y',
          serviceName: 'Y',
          cost: 120,
          currency: 'EUR',
          billingCycle: BillingCycle.yearly,
          nextRenewalDate: DateTime(2025, 1, 1),
        ),
        Subscription(
          id: 'w',
          serviceName: 'W',
          cost: 7,
          currency: 'EUR',
          billingCycle: BillingCycle.weekly,
          nextRenewalDate: DateTime(2025, 1, 1),
        ),
        Subscription(
          id: 'd',
          serviceName: 'D',
          cost: 1,
          currency: 'EUR',
          billingCycle: BillingCycle.daily,
          nextRenewalDate: DateTime(2025, 1, 1),
        ),
        Subscription(
          id: 'c',
          serviceName: 'C',
          cost: 30,
          currency: 'EUR',
          billingCycle: BillingCycle.custom,
          customCycleDays: 30,
          nextRenewalDate: DateTime(2025, 1, 1),
        ),
      ];

      final expectedMonthly = 10 + // monthly
          (120 / 12.0) + // yearly → monthly
          7 * weeksPerMonth + // weekly → monthly
          1 * daysPerMonthLocal + // daily → monthly
          30 * (daysPerMonthLocal / 30.0); // custom (N=30) → monthly

      final expectedYearly = 10 * 12.0 + // monthly → yearly
          120 + // yearly
          7 * weeksPerYear + // weekly → yearly
          1 * daysPerYear + // daily → yearly
          30 * (daysPerYear / 30.0); // custom (N=30) → yearly

      expect(totalMonthly(items), closeTo(expectedMonthly, eps));
      expect(totalYearly(items), closeTo(expectedYearly, eps));
    });

    test('custom N=1 ≈ daily; custom N=7 ≈ weekly (equivalence)', () {
      // Equivalence checks ensure custom mapping matches daily/weekly formulas.
      const weeksPerYear = daysPerYear / 7.0;
      const weeksPerMonth = weeksPerYear / monthsPerYear;
      const daysPerMonthLocal = daysPerYear / monthsPerYear;

      // N=1 behaves like daily.
      final custom1 = Subscription(
        id: 'c1',
        serviceName: 'C1',
        cost: 2.5,
        currency: 'EUR',
        billingCycle: BillingCycle.custom,
        customCycleDays: 1,
        nextRenewalDate: DateTime(2025, 1, 1),
      );
      expect(totalMonthly([custom1]), closeTo(2.5 * daysPerMonthLocal, eps));
      expect(totalYearly([custom1]), closeTo(2.5 * daysPerYear, eps));

      // N=7 behaves like weekly.
      final custom7 = Subscription(
        id: 'c7',
        serviceName: 'C7',
        cost: 14.0,
        currency: 'EUR',
        billingCycle: BillingCycle.custom,
        customCycleDays: 7,
        nextRenewalDate: DateTime(2025, 1, 1),
      );
      expect(totalMonthly([custom7]), closeTo(14.0 * weeksPerMonth, eps));
      expect(totalYearly([custom7]), closeTo(14.0 * weeksPerYear, eps));
    });

    test('customCycleDays ignored when cycle is not custom', () {
      final monthlyWithCustomField = Subscription(
        id: 'mc',
        serviceName: 'MC',
        cost: 8,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        customCycleDays: 3, // should not affect totals
        nextRenewalDate: DateTime(2025, 1, 1),
      );

      expect(totalMonthly([monthlyWithCustomField]), closeTo(8.0, eps));
      expect(totalYearly([monthlyWithCustomField]), closeTo(96.0, eps));
    });

    test('zero-cost items do not affect totals', () {
      final zeroMonthly = Subscription(
        id: 'z',
        serviceName: 'Z',
        cost: 0,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 1, 1),
      );
      final normal = Subscription(
        id: 'n',
        serviceName: 'N',
        cost: 9.99,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 1, 1),
      );

      expect(totalMonthly([zeroMonthly, normal]), closeTo(9.99, eps));
      expect(totalYearly([zeroMonthly, normal]), closeTo(9.99 * 12, eps));
    });

    test('order invariance (sum independent of item order)', () {
      final a = Subscription(
        id: 'a',
        serviceName: 'A',
        cost: 10,
        currency: 'EUR',
        billingCycle: BillingCycle.yearly,
        nextRenewalDate: DateTime(2025, 1, 1),
      );
      final b = Subscription(
        id: 'b',
        serviceName: 'B',
        cost: 7,
        currency: 'EUR',
        billingCycle: BillingCycle.weekly,
        nextRenewalDate: DateTime(2025, 1, 1),
      );

      expect(totalMonthly([a, b]), closeTo(totalMonthly([b, a]), eps));
      expect(totalYearly([a, b]), closeTo(totalYearly([b, a]), eps));
    });
  });
}
