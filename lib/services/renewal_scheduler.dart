import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/services/notification_service.dart';
import 'package:subscription_manager/utils/formatters.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

class RenewalScheduler {
  static Future<void> rescheduleAll(Iterable<Subscription> items) async {
    final settings = SettingsRepository().current;
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final l10n = await AppLocalizations.delegate.load(locale);

    for (final s in items) {
      await NotificationService().cancelForSubscription(s.id);
      await NotificationService().scheduleRenewalReminder(
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
