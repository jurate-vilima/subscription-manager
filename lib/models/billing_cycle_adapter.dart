import 'package:hive/hive.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

class BillingCycleAdapter extends TypeAdapter<BillingCycle> {
  @override
  final int typeId = 1;

  @override
  BillingCycle read(BinaryReader reader) =>
      BillingCycle.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, BillingCycle obj) {
    writer.writeByte(obj.index);
  }
}
