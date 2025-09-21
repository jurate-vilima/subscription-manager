import 'package:subscription_manager/models/billing_cycle.dart';

DateTime rollForward({
  required DateTime start,
  required BillingCycle cycle,
  int? customCycleDays,
  int? anchorDay,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  var next = start;

  while (!next.isAfter(reference)) {
    next = _addCycle(
      next,
      cycle,
      customCycleDays: customCycleDays,
      anchorDay: anchorDay,
    );
  }
  return next;
}

int _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime _withSameTime(DateTime base, int year, int month, int day) {
  return DateTime(
    year,
    month,
    day,
    base.hour,
    base.minute,
    base.second,
    base.millisecond,
    base.microsecond,
  );
}

DateTime _addCycle(
  DateTime date,
  BillingCycle cycle, {
  int? customCycleDays,
  int? anchorDay,
}) {
  switch (cycle) {
    case BillingCycle.daily:
      return date.add(const Duration(days: 1));

    case BillingCycle.weekly:
      return date.add(const Duration(days: 7));

    case BillingCycle.monthly:
      {
        final a = anchorDay ?? date.day;
        final rawNextMonth = date.month + 1;
        final nextYear = date.year + (rawNextMonth > 12 ? 1 : 0);
        final nextMonth = ((rawNextMonth - 1) % 12) + 1;
        final last = _lastDayOfMonth(nextYear, nextMonth);
        final d = (a <= last) ? a : last;
        return _withSameTime(date, nextYear, nextMonth, d);
      }

    case BillingCycle.yearly:
      {
        final nextYear = date.year + 1;
        final a = anchorDay ?? date.day;
        final last = _lastDayOfMonth(nextYear, date.month);
        final d = (a <= last) ? a : last;
        return _withSameTime(date, nextYear, date.month, d);
      }

    case BillingCycle.custom:
      {
        if (customCycleDays == null || customCycleDays <= 0) {
          throw ArgumentError.value(
            customCycleDays,
            'customCycleDays',
            'Must be a positive integer when cycle == BillingCycle.custom',
          );
        }
        return date.add(Duration(days: customCycleDays));
      }
  }
}
