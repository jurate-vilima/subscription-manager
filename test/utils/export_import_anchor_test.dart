import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_manager/utils/export_import.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

void main() {
  test('export/import keeps billingAnchorDay and upcases currency', () {
    final s = Subscription(
      id: 'id',
      serviceName: 'S',
      cost: 9.99,
      currency: 'eur',
      billingCycle: BillingCycle.monthly,
      nextRenewalDate: DateTime(2025, 1, 31, 8, 0),
      billingAnchorDay: 31,
    );
    final json = ExportImport.exportToJson([s]);
    final back = ExportImport.importFromJson(json);
    final r = back.single;
    expect(r.billingAnchorDay, 31);
    expect(r.currency, 'EUR');
  });
}
