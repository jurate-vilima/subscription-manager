import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/services/renewal_scheduler.dart';

Future<AppLocalizations> _loadL10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settings = AppSettings(
    leadDays: 3,
    notifyHour: 9,
    notifyMinute: 0,
    defaultCurrency: 'EUR',
  );
  const locale = Locale('en');

  group('RenewalScheduler.rescheduleAll (integration)', () {
    test(
      'does not throw for single monthly subscription (smoke)',
      () async {
        final cancelCalls = <String>[];
        final scheduleCalls = <Map<String, dynamic>>[];

        final subscription = Subscription(
          id: 's1',
          serviceName: 'Service A',
          cost: 1,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 3, 5, 12, 34),
        );

        await RenewalScheduler.rescheduleAll(
          [subscription],
          settingsOverride: settings,
          localeOverride: locale,
          l10nLoader: _loadL10n,
          cancelCallback: (id) async => cancelCalls.add(id),
          scheduleCallback: ({
            required String subscriptionId,
            required String title,
            required String body,
            required DateTime renewalDate,
            required int leadDays,
            required int notifyHour,
            required int notifyMinute,
          }) async {
            scheduleCalls.add({
              'id': subscriptionId,
              'title': title,
              'body': body,
              'renewal': renewalDate,
              'leadDays': leadDays,
              'hour': notifyHour,
              'minute': notifyMinute,
            });
          },
        );

        expect(cancelCalls, ['s1']);
        expect(scheduleCalls.single['id'], 's1');
      },
      tags: ['integration'],
    );

    test(
      'handles multiple subscriptions with diverse cycles',
      () async {
        final cancelCalls = <String>[];
        final scheduleCalls = <Map<String, dynamic>>[];

        final subs = <Subscription>[
          Subscription(
            id: 'm31',
            serviceName: 'Monthly 31',
            cost: 9.99,
            currency: 'EUR',
            billingCycle: BillingCycle.monthly,
            nextRenewalDate: DateTime(2025, 1, 31),
            billingAnchorDay: 31,
          ),
          Subscription(
            id: 'y29',
            serviceName: 'Yearly 29 Feb',
            cost: 19.99,
            currency: 'EUR',
            billingCycle: BillingCycle.yearly,
            nextRenewalDate: DateTime(2024, 2, 29),
            billingAnchorDay: 29,
          ),
          Subscription(
            id: 'w',
            serviceName: 'Weekly',
            cost: 4.99,
            currency: 'EUR',
            billingCycle: BillingCycle.weekly,
            nextRenewalDate: DateTime(2025, 3, 1),
          ),
          Subscription(
            id: 'd',
            serviceName: 'Daily',
            cost: 1.99,
            currency: 'EUR',
            billingCycle: BillingCycle.daily,
            nextRenewalDate: DateTime(2025, 3, 1),
          ),
          Subscription(
            id: 'c7',
            serviceName: 'Custom 7',
            cost: 2.99,
            currency: 'EUR',
            billingCycle: BillingCycle.custom,
            nextRenewalDate: DateTime(2025, 3, 1),
            customCycleDays: 7,
          ),
        ];

        await RenewalScheduler.rescheduleAll(
          subs,
          settingsOverride: settings,
          localeOverride: locale,
          l10nLoader: _loadL10n,
          cancelCallback: (id) async => cancelCalls.add(id),
          scheduleCallback: ({
            required String subscriptionId,
            required String title,
            required String body,
            required DateTime renewalDate,
            required int leadDays,
            required int notifyHour,
            required int notifyMinute,
          }) async {
            scheduleCalls.add({
              'id': subscriptionId,
              'renewal': renewalDate,
              'leadDays': leadDays,
              'hour': notifyHour,
              'minute': notifyMinute,
            });
          },
        );

        expect(cancelCalls.length, subs.length);
        expect(cancelCalls.toSet(), subs.map((s) => s.id).toSet());
        expect(scheduleCalls.length, subs.length);
      },
      tags: ['integration'],
    );

    test(
      'is idempotent w.r.t input objects',
      () async {
        final cancelCalls = <int>[];
        final scheduleCalls = <int>[];

        final original = Subscription(
          id: 'immut',
          serviceName: 'Immutable',
          cost: 5.00,
          currency: 'EUR',
          billingCycle: BillingCycle.monthly,
          nextRenewalDate: DateTime(2025, 2, 28),
          billingAnchorDay: 28,
        );
        final subs = [original];

        Future<void> run() => RenewalScheduler.rescheduleAll(
              subs,
              settingsOverride: settings,
              localeOverride: locale,
              l10nLoader: _loadL10n,
              cancelCallback: (id) async => cancelCalls.add(cancelCalls.length),
              scheduleCallback: ({
                required String subscriptionId,
                required String title,
                required String body,
                required DateTime renewalDate,
                required int leadDays,
                required int notifyHour,
                required int notifyMinute,
              }) async {
                scheduleCalls.add(scheduleCalls.length);
              },
            );

        await run();
        await run();

        expect(subs.first.id, original.id);
        expect(subs.first.serviceName, original.serviceName);
        expect(subs.first.cost, original.cost);
        expect(subs.first.currency, original.currency);
        expect(subs.first.billingCycle, original.billingCycle);
        expect(subs.first.nextRenewalDate, original.nextRenewalDate);
        expect(subs.first.billingAnchorDay, original.billingAnchorDay);
        expect(subs.first.customCycleDays, original.customCycleDays);
        expect(cancelCalls.length, 2);
        expect(scheduleCalls.length, 2);
      },
      tags: ['integration'],
    );
  });
}
