import 'package:uuid/uuid.dart';

import 'package:subscription_manager/data/subscription_repository.dart';
import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/services/notification_service.dart';
import 'package:subscription_manager/services/renewal_scheduler.dart';
import 'package:subscription_manager/utils/formatters.dart';
import 'package:subscription_manager/utils/rollover.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

class SubscriptionListViewModel extends ChangeNotifier {
  final SubscriptionRepository _repo;
  final SettingsRepository _settingsRepo;
  final NotificationService _notificationService;
  final Uuid _uuid;
  final Future<void> Function(Iterable<Subscription>) _reschedule;

  SubscriptionListViewModel({
    SubscriptionRepository? repo,
    SettingsRepository? settingsRepo,
    NotificationService? notificationService,
    Uuid? uuid,
    Future<void> Function(Iterable<Subscription>)? rescheduler,
  })  : _repo = repo ?? SubscriptionRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository(),
        _notificationService = notificationService ?? NotificationService(),
        _uuid = uuid ?? const Uuid(),
        _reschedule = rescheduler ?? RenewalScheduler.rescheduleAll;

  List<Subscription> _items = [];
  List<Subscription> get items => _items;

  void _sortByRenewal() {
    _items.sort((a, b) => a.nextRenewalDate.compareTo(b.nextRenewalDate));
  }

  Subscription? _lastDeleted;
  int _lastDeletedIndex = -1;

  Future<void> load() async {
    _items = _repo.getAll();
    final now = DateTime.now();

    for (var i = 0; i < _items.length; i++) {
      final s = _items[i];
      final rolled = rollForward(
        start: s.nextRenewalDate,
        cycle: s.billingCycle,
        customCycleDays: s.customCycleDays,
        anchorDay: s.billingAnchorDay,
        now: now,
      );
      if (rolled != s.nextRenewalDate) {
        final updated = s.copyWith(nextRenewalDate: rolled);
        await _repo.update(updated);
        _items[i] = updated;
      }
    }

    _sortByRenewal();
    notifyListeners();
    await _reschedule(_items);
  }

  Future<void> add({
    required String serviceName,
    required double cost,
    required String currency,
    required BillingCycle cycle,
    required DateTime nextRenewal,
    String? category,
    String? notes,
    String? url,
    int? customCycleDays,
    required AppLocalizations l10n,
  }) async {
    final s = Subscription(
      id: _uuid.v4(),
      serviceName: serviceName,
      cost: cost,
      currency: currency,
      billingCycle: cycle,
      nextRenewalDate: nextRenewal,
      category: category,
      notes: notes,
      cancellationUrl: url,
      customCycleDays: customCycleDays,
      billingAnchorDay:
          (cycle == BillingCycle.monthly || cycle == BillingCycle.yearly)
              ? nextRenewal.day
              : null,
    );

    await _repo.add(s);

    final settings = _settingsRepo.current;
    await _notificationService.scheduleRenewalReminder(
      subscriptionId: s.id,
      title: l10n.renewalReminderTitle(s.serviceName),
      body: l10n.renewalReminderBody(Formatters.dateShort(s.nextRenewalDate)),
      renewalDate: s.nextRenewalDate,
      leadDays: settings.leadDays,
      notifyHour: settings.notifyHour,
      notifyMinute: settings.notifyMinute,
    );

    _items.add(s);
    _sortByRenewal();
    notifyListeners();
  }

  Future<void> update(Subscription updated, AppLocalizations l10n) async {
    final withAnchor = (updated.billingCycle == BillingCycle.monthly ||
            updated.billingCycle == BillingCycle.yearly)
        ? updated.copyWith(billingAnchorDay: updated.nextRenewalDate.day)
        : updated.copyWith(billingAnchorDay: null);

    await _repo.update(withAnchor);

    final idx = _items.indexWhere((e) => e.id == withAnchor.id);
    if (idx >= 0) {
      _items[idx] = withAnchor;
      _sortByRenewal();

      final settings = _settingsRepo.current;
      await _notificationService.cancelForSubscription(withAnchor.id);
      await _notificationService.scheduleRenewalReminder(
        subscriptionId: withAnchor.id,
        title: l10n.renewalReminderTitle(withAnchor.serviceName),
        body: l10n.renewalReminderBody(
          Formatters.dateShort(withAnchor.nextRenewalDate),
        ),
        renewalDate: withAnchor.nextRenewalDate,
        leadDays: settings.leadDays,
        notifyHour: settings.notifyHour,
        notifyMinute: settings.notifyMinute,
      );

      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    await _repo.remove(id);
    await _notificationService.cancelForSubscription(id);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> removeWithMemory(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    _lastDeleted = _items[idx];
    _lastDeletedIndex = idx;

    await remove(id);
  }

  Future<void> undoLastDelete(AppLocalizations l10n) async {
    final s = _lastDeleted;
    if (s == null) return;

    _lastDeleted = null;
    final insertAt = _lastDeletedIndex < 0
        ? 0
        : (_lastDeletedIndex > _items.length
            ? _items.length
            : _lastDeletedIndex);

    _items.insert(insertAt, s);
    await _repo.add(s);
    _sortByRenewal();
    notifyListeners();

    final settings = _settingsRepo.current;
    await _notificationService.scheduleRenewalReminder(
      subscriptionId: s.id,
      title: l10n.renewalReminderTitle(s.serviceName),
      body: l10n.renewalReminderBody(Formatters.dateShort(s.nextRenewalDate)),
      renewalDate: s.nextRenewalDate,
      leadDays: settings.leadDays,
      notifyHour: settings.notifyHour,
      notifyMinute: settings.notifyMinute,
    );
  }

  Future<void> addFromImport(Subscription s) async {
    await _repo.add(s);
    _items.add(s);
    _sortByRenewal();
  }

  Future<void> replaceAllFromImport(List<Subscription> newItems) async {
    for (final old in List<Subscription>.from(_items)) {
      await remove(old.id);
    }
    for (final s in newItems) {
      await addFromImport(s);
    }
    _sortByRenewal();
    notifyListeners();

    final settings = _settingsRepo.current;
    final l10n = await AppLocalizations.delegate.load(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    for (final s in _items) {
      await _notificationService.scheduleRenewalReminder(
        subscriptionId: s.id,
        title: l10n.renewalReminderTitle(s.serviceName),
        body: l10n.renewalReminderBody(Formatters.dateShort(s.nextRenewalDate)),
        renewalDate: s.nextRenewalDate,
        leadDays: settings.leadDays,
        notifyHour: settings.notifyHour,
        notifyMinute: settings.notifyMinute,
      );
    }
  }
}
