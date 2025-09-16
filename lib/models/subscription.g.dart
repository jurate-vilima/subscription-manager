// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubscriptionAdapter extends TypeAdapter<Subscription> {
  @override
  final int typeId = 0;

  @override
  Subscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subscription(
      id: fields[0] as String,
      serviceName: fields[1] as String,
      cost: fields[2] as double,
      currency: fields[3] as String,
      billingCycle: fields[4] as BillingCycle,
      nextRenewalDate: fields[5] as DateTime,
      category: fields[6] as String?,
      notes: fields[7] as String?,
      cancellationUrl: fields[8] as String?,
      customCycleDays: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Subscription obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.serviceName)
      ..writeByte(2)
      ..write(obj.cost)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.billingCycle)
      ..writeByte(5)
      ..write(obj.nextRenewalDate)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.cancellationUrl)
      ..writeByte(9)
      ..write(obj.customCycleDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
