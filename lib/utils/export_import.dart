import 'dart:convert';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

class ExportImport {
  static String exportToJson(List<Subscription> items) {
    final list = items
        .map(
          (s) => {
            'id': s.id,
            'serviceName': s.serviceName,
            'cost': s.cost,
            'currency': s.currency,
            'billingCycle': s.billingCycle.name,
            'nextRenewalDate': s.nextRenewalDate.toIso8601String(),
            'category': s.category,
            'notes': s.notes,
            'cancellationUrl': s.cancellationUrl,
            'customCycleDays': s.customCycleDays,
          },
        )
        .toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  static List<Subscription> importFromJson(String jsonStr) {
    final raw = json.decode(jsonStr) as List<dynamic>;
    return raw.map((m) {
      final map = m as Map<String, dynamic>;
      final currency = (map['currency'] as String).toUpperCase();
      if (currency.length != 3) {
        throw const FormatException('Invalid currency code');
      }
      return Subscription(
        id: map['id'] as String,
        serviceName: map['serviceName'] as String,
        cost: (map['cost'] as num).toDouble(),
        currency: currency,
        billingCycle: _cycleFromName(map['billingCycle'] as String),
        nextRenewalDate: DateTime.parse(map['nextRenewalDate'] as String),
        category: map['category'] as String?,
        notes: map['notes'] as String?,
        cancellationUrl: map['cancellationUrl'] as String?,
        customCycleDays: (map['customCycleDays'] as num?)?.toInt(),
      );
    }).toList();
  }

  static BillingCycle _cycleFromName(String name) {
    return BillingCycle.values.firstWhere(
      (e) => e.name == name,
      orElse: () => BillingCycle.monthly,
    );
  }
}
