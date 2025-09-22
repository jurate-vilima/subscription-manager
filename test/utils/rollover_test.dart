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

  group('rollForward (multi-step / far-in-the-past)', () {
    test('monthly multi-step: rolls to nearest future just beyond now', () {
      final start = DateTime(2023, 1, 31, 10, 15);
      final now = DateTime(2023, 12, 15, 9, 00);

      final next = rollForward(
        start: start,
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        now: now,
      );

      expect(next, DateTime(2023, 12, 31, 10, 15));
      expect(next.isAfter(now), isTrue);
    });

    test('custom multi-step: finds the first slot after now', () {
      final start = DateTime(2025, 1, 1, 9, 0);
      final now = DateTime(2025, 1, 20, 9, 0);
      final next = rollForward(
        start: start,
        cycle: BillingCycle.custom,
        customCycleDays: 7,
        now: now,
      );
      expect(next, DateTime(2025, 1, 22, 9, 0));
    });
  });

  group('rollForward (monthly invariant over a whole year)', () {
    test('keeps anchor or clamps to month-end; preserves hh:mm:ss.mmm', () {
      final start = DateTime(2025, 1, 31, 7, 45, 12, 345);
      var current = start;
      var now = DateTime(2025, 1, 1);

      for (var i = 0; i < 12; i++) {
        final next = rollForward(
          start: current,
          cycle: BillingCycle.monthly,
          anchorDay: 31,
          now: now,
        );
        final lastDay = DateTime(next.year, next.month + 1, 0).day;
        expect(next.day, anyOf(31, lastDay), reason: 'month=${next.month}');
        expect(next.hour, 7);
        expect(next.minute, 45);
        expect(next.second, 12);
        expect(next.millisecond, 345);

        now = next;
        current = next;
      }
    });
  });

  group('rollForward (anchorDay ignored for non-monthly/yearly)', () {
    final start = DateTime(2025, 3, 30, 10, 00);

    test('daily ignores anchorDay', () {
      final next = rollForward(
        start: start,
        cycle: BillingCycle.daily,
        anchorDay: 31,
        now: start,
      );
      expect(next, start.add(const Duration(days: 1)));
    });

    test('weekly ignores anchorDay', () {
      final next = rollForward(
        start: start,
        cycle: BillingCycle.weekly,
        anchorDay: 1,
        now: start,
      );
      expect(next, start.add(const Duration(days: 7)));
    });

    test('custom ignores anchorDay', () {
      final next = rollForward(
        start: start,
        cycle: BillingCycle.custom,
        customCycleDays: 10,
        anchorDay: 15,
        now: start,
      );
      expect(next, start.add(const Duration(days: 10)));
    });
  });

  group('rollForward (strictly future relative to now)', () {
    final base = DateTime(2025, 5, 10, 12, 0);

    test('daily is strictly after now', () {
      final next =
          rollForward(start: base, cycle: BillingCycle.daily, now: base);
      expect(next.isAfter(base), isTrue);
      expect(next.isAtSameMomentAs(base), isFalse);
    });

    test('weekly is strictly after now', () {
      final next =
          rollForward(start: base, cycle: BillingCycle.weekly, now: base);
      expect(next.difference(base), const Duration(days: 7));
      expect(next.isAfter(base), isTrue);
    });

    test('monthly (anchor=null) uses start.day and is after now', () {
      final next =
          rollForward(start: base, cycle: BillingCycle.monthly, now: base);
      expect(next.day, base.day);
      expect(next.isAfter(base), isTrue);
    });

    test('yearly (anchor=null) uses start.day (clamped) and is after now', () {
      final next =
          rollForward(start: base, cycle: BillingCycle.yearly, now: base);
      expect(next.month, base.month);
      final lastDay = DateTime(next.year, next.month + 1, 0).day;
      expect(next.day, anyOf(base.day, lastDay));
      expect(next.isAfter(base), isTrue);
    });
  });

  group(
      'rollForward (yearly preserves anchor and returns to Feb-29 on leap years)',
      () {
    test('2024-02-29 -> 2025-02-28 -> 2026-02-28 -> 2027-02-28 -> 2028-02-29',
        () {
      final start = DateTime(2024, 2, 29, 8, 30);

      final y2025 = rollForward(
        start: start,
        cycle: BillingCycle.yearly,
        anchorDay: 29,
        now: start,
      );
      expect(y2025, DateTime(2025, 2, 28, 8, 30));

      final y2026 = rollForward(
        start: y2025,
        cycle: BillingCycle.yearly,
        anchorDay: 29,
        now: y2025,
      );
      expect(y2026, DateTime(2026, 2, 28, 8, 30));

      final y2027 = rollForward(
        start: y2026,
        cycle: BillingCycle.yearly,
        anchorDay: 29,
        now: y2026,
      );
      expect(y2027, DateTime(2027, 2, 28, 8, 30));

      final y2028 = rollForward(
        start: y2027,
        cycle: BillingCycle.yearly,
        anchorDay: 29,
        now: y2027,
      );
      expect(y2028, DateTime(2028, 2, 29, 8, 30));
    });
  });

  group('rollForward (monthly returns to 31 after 30-clamp)', () {
    test('2025-04-30 -> 2025-05-31 with anchor=31', () {
      final apr30 = DateTime(2025, 4, 30, 10, 15);
      final may = rollForward(
        start: apr30,
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        now: apr30,
      );
      expect(may, DateTime(2025, 5, 31, 10, 15));
    });
  });

  group('rollForward (monthly start 29 across feb)', () {
    test('2025-01-29 -> 2025-02-28 -> 2025-03-29 (non-leap)', () {
      final jan29 = DateTime(2025, 1, 29, 9, 0);
      final feb = rollForward(
        start: jan29,
        cycle: BillingCycle.monthly,
        anchorDay: 29,
        now: jan29,
      );
      final mar = rollForward(
        start: feb,
        cycle: BillingCycle.monthly,
        anchorDay: 29,
        now: feb,
      );
      expect(feb, DateTime(2025, 2, 28, 9, 0));
      expect(mar, DateTime(2025, 3, 29, 9, 0));
    });

    test('2024-01-29 -> 2024-02-29 -> 2024-03-29 (leap)', () {
      final jan29 = DateTime(2024, 1, 29, 9, 0);
      final feb = rollForward(
        start: jan29,
        cycle: BillingCycle.monthly,
        anchorDay: 29,
        now: jan29,
      );
      final mar = rollForward(
        start: feb,
        cycle: BillingCycle.monthly,
        anchorDay: 29,
        now: feb,
      );
      expect(feb, DateTime(2024, 2, 29, 9, 0));
      expect(mar, DateTime(2024, 3, 29, 9, 0));
    });
  });

  group('rollForward (yearly invariant on non-feb months)', () {
    test('anchor=15 keeps day across years', () {
      final start = DateTime(2023, 7, 15, 8, 30);
      final y1 = rollForward(
          start: start, cycle: BillingCycle.yearly, anchorDay: 15, now: start);
      final y2 = rollForward(
          start: y1, cycle: BillingCycle.yearly, anchorDay: 15, now: y1);
      final y3 = rollForward(
          start: y2, cycle: BillingCycle.yearly, anchorDay: 15, now: y2);
      expect(y1, DateTime(2024, 7, 15, 8, 30));
      expect(y2, DateTime(2025, 7, 15, 8, 30));
      expect(y3, DateTime(2026, 7, 15, 8, 30));
    });

    test('anchor=31 stays safe in same month', () {
      final start = DateTime(2023, 8, 31, 6, 0);
      final y1 = rollForward(
          start: start, cycle: BillingCycle.yearly, anchorDay: 31, now: start);
      final y2 = rollForward(
          start: y1, cycle: BillingCycle.yearly, anchorDay: 31, now: y1);
      expect(y1, DateTime(2024, 8, 31, 6, 0));
      expect(y2, DateTime(2025, 8, 31, 6, 0));
    });
  });

  group('rollForward (yearly without anchor uses start.day)', () {
    test('start on 2023-02-29 equivalent clamps to 28 and stays until leap',
        () {
      final start = DateTime(2024, 2, 29, 7, 45);
      final y1 =
          rollForward(start: start, cycle: BillingCycle.yearly, now: start);
      final y2 = rollForward(start: y1, cycle: BillingCycle.yearly, now: y1);
      final y3 = rollForward(start: y2, cycle: BillingCycle.yearly, now: y2);
      final y4 = rollForward(start: y3, cycle: BillingCycle.yearly, now: y3);
      expect(y1, DateTime(2025, 2, 28, 7, 45));
      expect(y2, DateTime(2026, 2, 28, 7, 45));
      expect(y3, DateTime(2027, 2, 28, 7, 45));
      expect(y4,
          anyOf(DateTime(2028, 2, 28, 7, 45), DateTime(2028, 2, 29, 7, 45)));
    });
  });

  group('rollForward (strict future when start > now)', () {
    test('returns strictly after now when start is already in the future', () {
      final start = DateTime(2025, 5, 10, 12, 0);
      final now = start.subtract(const Duration(hours: 1));
      final next = rollForward(
          start: start, cycle: BillingCycle.monthly, anchorDay: 10, now: now);
      expect(next.isAfter(now), isTrue);
      expect(next.isAtSameMomentAs(now), isFalse);
    });
  });

  group('rollForward (idempotency for same now)', () {
    test('calling twice with same now does not jump twice', () {
      final base = DateTime(2025, 1, 31, 9, 0);
      final now = DateTime(2025, 1, 31, 9, 0);
      final n1 = rollForward(
          start: base, cycle: BillingCycle.monthly, anchorDay: 31, now: now);
      final n2 = rollForward(
          start: n1, cycle: BillingCycle.monthly, anchorDay: 31, now: now);
      expect(n2, n1);
    });
  });
}
