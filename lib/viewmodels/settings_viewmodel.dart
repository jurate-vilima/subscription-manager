import 'package:flutter/foundation.dart';
import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/data/subscription_repository.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/services/renewal_scheduler.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _repo;
  final SubscriptionRepository _subRepo;
  final Future<void> Function(Iterable<Subscription>) _reschedule;

  SettingsViewModel({
    SettingsRepository? settingsRepo,
    SubscriptionRepository? subscriptionRepo,
    Future<void> Function(Iterable<Subscription>)? rescheduler,
  }) : _repo = settingsRepo ?? SettingsRepository(),
       _subRepo = subscriptionRepo ?? SubscriptionRepository(),
       _reschedule = rescheduler ?? RenewalScheduler.rescheduleAll {
    _state = _repo.current;
  }

  late AppSettings _state;
  AppSettings get state => _state;

  void reload() {
    _state = _repo.current;
    notifyListeners();
  }

  Future<void> update({
    String? defaultCurrency,
    int? leadDays,
    String? themeMode,
    int? notifyHour,
    int? notifyMinute,
    String? localeCode,
  }) async {
    var next = _state;

    bool schedulingChanged = false;

    if (defaultCurrency != null) {
      final v = defaultCurrency.trim().toUpperCase();
      if (v.length == 3) next = next.copyWith(defaultCurrency: v);
    }
    if (leadDays != null && leadDays >= 0 && leadDays <= 30) {
      next = next.copyWith(leadDays: leadDays);
      schedulingChanged = true;
    }
    if (themeMode != null &&
        (themeMode == 'system' ||
            themeMode == 'light' ||
            themeMode == 'dark')) {
      next = next.copyWith(themeMode: themeMode);
    }
    if (localeCode != null &&
        (localeCode == 'en' || localeCode == 'lv' || localeCode == 'ru')) {
      next = next.copyWith(localeCode: localeCode);
    }
    if (notifyHour != null && notifyHour >= 0 && notifyHour <= 23) {
      next = next.copyWith(notifyHour: notifyHour);
      schedulingChanged = true;
    }
    if (notifyMinute != null && notifyMinute >= 0 && notifyMinute <= 59) {
      next = next.copyWith(notifyMinute: notifyMinute);
      schedulingChanged = true;
    }

    _state = next;
    await _repo.save(_state);
    notifyListeners();

    if (schedulingChanged) {
      final items = _subRepo.getAll();
      await _reschedule(items);
    }
  }

  Future<void> setLeadDays(int days) async {
    if (days < 0 || days > 30) return;
    _state = _state.copyWith(leadDays: days);
    await _repo.save(_state);
    notifyListeners();
    final items = _subRepo.getAll();
    await _reschedule(items);
  }

  Future<void> setDefaultCurrency(String value) async {
    final v = value.trim().toUpperCase();
    if (v.length != 3) return;
    _state = _state.copyWith(defaultCurrency: v);
    await _repo.save(_state);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    if (mode != 'system' && mode != 'light' && mode != 'dark') return;
    _state = _state.copyWith(themeMode: mode);
    await _repo.save(_state);
    notifyListeners();
  }

  Future<void> setLocaleCode(String code) async {
    if (code != 'en' && code != 'lv' && code != 'ru') return;
    _state = _state.copyWith(localeCode: code);
    await _repo.save(_state);
    notifyListeners();
  }

  Future<void> setNotifyHour(int hour) async {
    if (hour < 0 || hour > 23) return;
    _state = _state.copyWith(notifyHour: hour);
    await _repo.save(_state);
    notifyListeners();
    final items = _subRepo.getAll();
    await _reschedule(items);
  }

  Future<void> setNotifyMinute(int minute) async {
    if (minute < 0 || minute > 59) return;
    _state = _state.copyWith(notifyMinute: minute);
    await _repo.save(_state);
    notifyListeners();
    final items = _subRepo.getAll();
    await _reschedule(items);
  }
}
