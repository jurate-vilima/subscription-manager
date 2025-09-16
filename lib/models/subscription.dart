import 'package:hive/hive.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

part 'subscription.g.dart';

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
  });

  Subscription copyWith({
    String? id,
    String? serviceName,
    double? cost,
    String? currency,
    BillingCycle? billingCycle,
    DateTime? nextRenewalDate,
    String? category,
    String? notes,
    String? cancellationUrl,
    int? customCycleDays,
  }) {
    return Subscription(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      billingCycle: billingCycle ?? this.billingCycle,
      nextRenewalDate: nextRenewalDate ?? this.nextRenewalDate,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      cancellationUrl: cancellationUrl ?? this.cancellationUrl,
      customCycleDays: customCycleDays ?? this.customCycleDays,
    );
  }
}
