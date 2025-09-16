import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings {
  @HiveField(0)
  final int leadDays;

  @HiveField(1)
  final String defaultCurrency;

  @HiveField(2)
  final String themeMode;

  @HiveField(3, defaultValue: 10)
  final int notifyHour;

  @HiveField(4, defaultValue: 0)
  final int notifyMinute;

  @HiveField(5, defaultValue: 'lv')
  final String localeCode;

  const AppSettings({
    this.leadDays = 3,
    this.defaultCurrency = 'EUR',
    this.themeMode = 'system',
    this.notifyHour = 10,
    this.notifyMinute = 0,
    this.localeCode = 'lv',
  });

  AppSettings copyWith({
    int? leadDays,
    String? defaultCurrency,
    String? themeMode,
    int? notifyHour,
    int? notifyMinute,
    String? localeCode,
  }) {
    return AppSettings(
      leadDays: leadDays ?? this.leadDays,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      themeMode: themeMode ?? this.themeMode,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      localeCode: localeCode ?? this.localeCode,
    );
  }
}
