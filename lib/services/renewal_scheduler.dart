import 'package:flutter/widgets.dart';
import 'package:subscription_manager/data/settings_repository.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/services/notification_service.dart';
import 'package:subscription_manager/utils/formatters.dart';

class RenewalScheduler {
  static Future<void> rescheduleAll(
    Iterable<Subscription> items, {
    AppSettings? settingsOverride,
    Locale? localeOverride,
    Future<AppLocalizations> Function(Locale locale)? l10nLoader,
    Future<void> Function(String subscriptionId)? cancelCallback,
    Future<void> Function({
      required String subscriptionId,
      required String title,
      required String body,
      required DateTime renewalDate,
      required int leadDays,
      required int notifyHour,
      required int notifyMinute,
    })? scheduleCallback,
  }) async {
    final settings = settingsOverride ?? SettingsRepository().current;
    final locale =
        localeOverride ?? WidgetsBinding.instance.platformDispatcher.locale;
    final loadLocalization = l10nLoader ?? AppLocalizations.delegate.load;
    final l10n = await loadLocalization(locale);

    final notificationService = NotificationService();
    final cancel = cancelCallback ?? notificationService.cancelForSubscription;
    final schedule = scheduleCallback ??
        ({
          required String subscriptionId,
          required String title,
          required String body,
          required DateTime renewalDate,
          required int leadDays,
          required int notifyHour,
          required int notifyMinute,
        }) async {
          await notificationService.scheduleRenewalReminder(
            subscriptionId: subscriptionId,
            title: title,
            body: body,
            renewalDate: renewalDate,
            leadDays: leadDays,
            notifyHour: notifyHour,
            notifyMinute: notifyMinute,
          );
        };

    for (final subscription in items) {
      await cancel(subscription.id);
      await schedule(
        subscriptionId: subscription.id,
        title: l10n.renewalReminderTitle(subscription.serviceName),
        body: l10n.renewalReminderBody(
          Formatters.dateShort(subscription.nextRenewalDate),
        ),
        renewalDate: subscription.nextRenewalDate,
        leadDays: settings.leadDays,
        notifyHour: settings.notifyHour,
        notifyMinute: settings.notifyMinute,
      );
    }
  }
}
