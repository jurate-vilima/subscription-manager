import 'package:subscription_manager/models/billing_cycle.dart';

DateTime rollForward({
  required DateTime start,
  required BillingCycle cycle,
  int? customCycleDays,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  var next = start;
  while (!next.isAfter(reference)) {
    next = _addCycle(next, cycle, customCycleDays);
  }
  return next;
}

DateTime _addCycle(DateTime date, BillingCycle cycle, int? customCycleDays) {
  switch (cycle) {
    case BillingCycle.daily:
      return date.add(const Duration(days: 1));
    case BillingCycle.weekly:
      return date.add(const Duration(days: 7));
    case BillingCycle.monthly:
      return DateTime(date.year, date.month + 1, date.day);
    case BillingCycle.yearly:
      return DateTime(date.year + 1, date.month, date.day);
    case BillingCycle.custom:
      final days = customCycleDays ?? 0;
      if (days > 0) {
        return date.add(Duration(days: days));
      } else {
        return DateTime(date.year, date.month + 1, date.day);
      }
  }
}
