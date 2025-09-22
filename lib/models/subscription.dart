import 'package:hive/hive.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

part 'subscription.g.dart';

const _unset = Object();

@HiveType(typeId: 0)
class Subscription {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String serviceName;

  @HiveField(2)
  final double cost;

  @HiveField(3)
  final String currency;

  @HiveField(4)
  final BillingCycle billingCycle;

  @HiveField(5)
  final DateTime nextRenewalDate;

  @HiveField(6)
  final String? category;

  @HiveField(7)
  final String? notes;

  @HiveField(8)
  final String? cancellationUrl;

  @HiveField(9)
  final int? customCycleDays;

  @HiveField(10)
  final int? billingAnchorDay;

  const Subscription({
    required this.id,
    required this.serviceName,
    required this.cost,
    required this.currency,
    required this.billingCycle,
    required this.nextRenewalDate,
    this.category,
    this.notes,
    this.cancellationUrl,
    this.customCycleDays,
    this.billingAnchorDay,
  });

  Subscription copyWith({
    String? id,
    String? serviceName,
    double? cost,
    String? currency,
    BillingCycle? billingCycle,
    DateTime? nextRenewalDate,
    Object? category = _unset,
    Object? notes = _unset,
    Object? cancellationUrl = _unset,
    Object? customCycleDays = _unset,
    Object? billingAnchorDay = _unset,
  }) {
    return Subscription(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      billingCycle: billingCycle ?? this.billingCycle,
      nextRenewalDate: nextRenewalDate ?? this.nextRenewalDate,
      category:
          identical(category, _unset) ? this.category : category as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      cancellationUrl: identical(cancellationUrl, _unset)
          ? this.cancellationUrl
          : cancellationUrl as String?,
      customCycleDays: identical(customCycleDays, _unset)
          ? this.customCycleDays
          : customCycleDays as int?,
      billingAnchorDay: identical(billingAnchorDay, _unset)
          ? this.billingAnchorDay
          : billingAnchorDay as int?,
    );
  }
}
