import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_manager/utils/rollover.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

void main() {
  group('rollForward (monthly EoM & leap-year)', () {
    test('31 Jan 2023 → 28 Feb 2023 → 31 Mar 2023 (monthly, anchor=31)', () {
      final jan31 = DateTime(2023, 1, 31, 10, 15);

      final feb = rollForward(
        start: jan31,
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        now: jan31,
      );

      final mar = rollForward(
        start: feb,
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        now: feb,
      );

      expect(feb, DateTime(2023, 2, 28, 10, 15));
      expect(mar, DateTime(2023, 3, 31, 10, 15));
    });

    test('31 Jan 2024 (leap) → 29 Feb 2024 (monthly, anchor=31)', () {
      final jan31 = DateTime(2024, 1, 31, 10, 15);

      final feb = rollForward(
        start: jan31,
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        now: jan31,
      );

      expect(feb, DateTime(2024, 2, 29, 10, 15));
    });

    test('30 Jan 2023 → 28 Feb 2023 → 30 Mar 2023 (monthly, anchor=30)', () {
      final jan30 = DateTime(2023, 1, 30, 10, 15);

      final feb = rollForward(
        start: jan30,
        cycle: BillingCycle.monthly,
        anchorDay: 30,
        now: jan30,
      );

      final mar = rollForward(
        start: feb,
        cycle: BillingCycle.monthly,
        anchorDay: 30,
        now: feb,
      );

      expect(feb, DateTime(2023, 2, 28, 10, 15));
      expect(mar, DateTime(2023, 3, 30, 10, 15));
    });
  });

  group('rollForward (custom cycle days)', () {
    test('custom +N days preserves hh:mm for N in {1,3,7,10,45}', () {
      final start = DateTime(2025, 3, 30, 10, 00);
      for (final n in [1, 3, 7, 10, 45]) {
        final next = rollForward(
          start: start,
          cycle: BillingCycle.custom,
          customCycleDays: n,
          now: start,
        );
        expect(next, start.add(Duration(days: n)),
            reason: 'Failed for customCycleDays=$n');
      }
    });

    test('custom with null/zero/negative days throws', () {
      final start = DateTime(2025, 3, 30, 10, 00);
      expect(
        () => rollForward(start: start, cycle: BillingCycle.custom, now: start),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => rollForward(
            start: start,
            cycle: BillingCycle.custom,
            customCycleDays: 0,
            now: start),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => rollForward(
            start: start,
            cycle: BillingCycle.custom,
            customCycleDays: -5,
            now: start),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('rollForward (yearly clamp)', () {
    test('29 Feb 2024 → 28 Feb 2025 (non-leap clamp)', () {
      final feb29Leap = DateTime(2024, 2, 29, 8, 30);
      final next = rollForward(
        start: feb29Leap,
        cycle: BillingCycle.yearly,
        now: feb29Leap,
      );
      expect(next, DateTime(2025, 2, 28, 8, 30));
    });
  });
}
