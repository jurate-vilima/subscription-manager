import 'package:hive/hive.dart';
import 'package:subscription_manager/models/app_settings.dart';

class SettingsRepository {
  static const _boxName = 'settings';
  static const _key = 'app';

  Box<AppSettings> get _box => Hive.box<AppSettings>(_boxName);

  AppSettings get current {
    final s = _box.get(_key);
    return s ?? const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    await _box.put(_key, settings);
  }
}
