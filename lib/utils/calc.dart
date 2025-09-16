import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

const double daysPerYear = 365.25;
const double monthsPerYear = 12.0;
const double weeksPerYear = daysPerYear / 7.0;
const double weeksPerMonth = weeksPerYear / monthsPerYear;
const double daysPerMonth = daysPerYear / monthsPerYear;

double totalMonthly(List<Subscription> items) {
  double sum = 0;
  for (final s in items) {
    switch (s.billingCycle) {
      case BillingCycle.monthly:
        sum += s.cost;
        break;
      case BillingCycle.yearly:
        sum += s.cost / monthsPerYear;
        break;
      case BillingCycle.weekly:
        sum += s.cost * weeksPerMonth;
        break;
      case BillingCycle.daily:
        sum += s.cost * daysPerMonth;
        break;
      case BillingCycle.custom:
        final days = s.customCycleDays;
        if (days != null && days > 0) {
          sum += s.cost * (daysPerMonth / days);
        } else {
          sum += s.cost;
        }
        break;
    }
  }
  return sum;
}

double totalYearly(List<Subscription> items) {
  double sum = 0;
  for (final s in items) {
    switch (s.billingCycle) {
      case BillingCycle.monthly:
        sum += s.cost * monthsPerYear;
        break;
      case BillingCycle.yearly:
        sum += s.cost;
        break;
      case BillingCycle.weekly:
        sum += s.cost * weeksPerYear;
        break;
      case BillingCycle.daily:
        sum += s.cost * daysPerYear;
        break;
      case BillingCycle.custom:
        final days = s.customCycleDays;
        if (days != null && days > 0) {
          sum += s.cost * (daysPerYear / days);
        } else {
          sum += s.cost * monthsPerYear;
        }
        break;
    }
  }
  return sum;
}
