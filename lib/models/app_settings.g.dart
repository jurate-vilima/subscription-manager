// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      leadDays: fields[0] as int,
      defaultCurrency: fields[1] as String,
      themeMode: fields[2] as String,
      notifyHour: fields[3] == null ? 10 : fields[3] as int,
      notifyMinute: fields[4] == null ? 0 : fields[4] as int,
      localeCode: fields[5] == null ? 'lv' : fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.leadDays)
      ..writeByte(1)
      ..write(obj.defaultCurrency)
      ..writeByte(2)
      ..write(obj.themeMode)
      ..writeByte(3)
      ..write(obj.notifyHour)
      ..writeByte(4)
      ..write(obj.notifyMinute)
      ..writeByte(5)
      ..write(obj.localeCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
