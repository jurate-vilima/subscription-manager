import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_manager/utils/rollover.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

void main() {
  test('31 Mar 2023 -> 31 Mar 2024 (yearly, anchor=31, keep time)', () {
    final start = DateTime(2023, 3, 31, 10, 15);
    final next = rollForward(
      start: start,
      cycle: BillingCycle.yearly,
      anchorDay: 31,
      now: start,
    );
    expect(next, DateTime(2024, 3, 31, 10, 15));
  });

  test('29 Feb 2024 -> 28 Feb 2025 (yearly, anchor=29; clamp non-leap)', () {
    final leap = DateTime(2024, 2, 29, 8, 30);
    final next = rollForward(
      start: leap,
      cycle: BillingCycle.yearly,
      anchorDay: 29,
      now: leap,
    );
    expect(next, DateTime(2025, 2, 28, 8, 30));
  });
}
