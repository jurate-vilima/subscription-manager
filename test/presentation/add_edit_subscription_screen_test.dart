import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/presentation/screens/add_edit_subscription_screen.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';

import '../support/test_doubles.dart';
import '../support/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(DateTime(2025, 1, 1));
  });

  group('AddEditSubscriptionScreen', () {
    late MockNotificationService notification;
    late FakeSubscriptionRepository subsRepo;
    late FakeSettingsRepository settingsRepo;
    late RecordingRescheduler rescheduler;
    late SubscriptionListViewModel listVm;
    late SettingsViewModel settingsVm;

    Future<void> pumpScreen(WidgetTester tester, {String? editId}) async {
      await pumpWidgetHarness(
        tester,
        home: AddEditSubscriptionScreen(editId: editId),
        providers: [
          ChangeNotifierProvider<SubscriptionListViewModel>.value(
            value: listVm,
          ),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVm),
        ],
      );
      await tester.pumpAndSettle();
    }

    Finder field(String key) => find.byKey(ValueKey(key));
    Finder editable(String key) => find.descendant(
          of: field(key),
          matching: find.byType(EditableText),
        );

    Future<void> enter(WidgetTester tester, String key, String text) async {
      await tester.ensureVisible(field(key));
      final input = editable(key);
      expect(input, findsOneWidget);
      await tester.enterText(input, text);
      await tester.pump();
    }

    setUp(() async {
      notification = stubNotificationService();
      subsRepo = FakeSubscriptionRepository();
      settingsRepo = FakeSettingsRepository(
        const AppSettings(
          defaultCurrency: 'GBP',
          leadDays: 4,
          notifyHour: 8,
          notifyMinute: 15,
        ),
      );
      rescheduler = RecordingRescheduler();
      listVm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notification,
        rescheduler: rescheduler.call,
      );
      await listVm.load();

      settingsVm = SettingsViewModel(
        settingsRepo: settingsRepo,
        subscriptionRepo: subsRepo,
        rescheduler: rescheduler.call,
      );
    });

    testWidgets('prefills defaults and schedules new subscription',
        (tester) async {
      await pumpScreen(tester);

      final screenContext =
          tester.element(find.byType(AddEditSubscriptionScreen));
      final l10n = AppLocalizations.of(screenContext)!;

      final currencyWidget = tester.widget<TextFormField>(
        field('currencyField'),
      );
      expect(currencyWidget.controller!.text, 'GBP');

      await enter(tester, 'serviceNameField', 'Spotify');
      await enter(tester, 'costField', '12.50');

      await tester.tap(find.byType(DropdownButtonFormField<BillingCycle>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cycleCustom));
      await tester.pumpAndSettle();
      await enter(tester, 'intervalField', '10');

      await tester.tap(find.text(l10n.pick));
      await tester.pumpAndSettle();
      final targetDate = DateTime.now().add(const Duration(days: 5));
      await tester.tap(find.text('${targetDate.day}').last);
      await tester.pumpAndSettle();
      final okLabel = MaterialLocalizations.of(
        tester.element(find.byType(CalendarDatePicker)),
      ).okButtonLabel;
      await tester.tap(find.text(okLabel));
      await tester.pumpAndSettle();

      await enter(tester, 'categoryField', 'Entertainment');
      await enter(tester, 'urlField', 'https://example.com/cancel');

      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      final saved = subsRepo.getAll().single;
      expect(saved.serviceName, 'Spotify');
      expect(saved.cost, 12.5);
      expect(saved.currency, 'GBP');
      expect(saved.billingCycle, BillingCycle.custom);
      expect(saved.customCycleDays, 10);
      expect(saved.category, 'Entertainment');
      expect(saved.cancellationUrl, 'https://example.com/cancel');

      verify(() => notification.scheduleRenewalReminder(
            subscriptionId: any(named: 'subscriptionId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            renewalDate: any(named: 'renewalDate'),
            leadDays: 4,
            notifyHour: 8,
            notifyMinute: 15,
          )).called(1);
    });

    testWidgets('edits existing subscription and reschedules notification',
        (tester) async {
      final existing = Subscription(
        id: 'existing-id',
        serviceName: 'Netflix',
        cost: 9.99,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime.now().add(const Duration(days: 30)),
        category: 'Streaming',
        cancellationUrl: 'https://netflix.com/cancel',
        notes: 'HD',
      );
      await subsRepo.add(existing);
      await listVm.load();

      await pumpScreen(tester, editId: existing.id);

      final screenContext =
          tester.element(find.byType(AddEditSubscriptionScreen));
      final l10n = AppLocalizations.of(screenContext)!;

      expect(
        tester
            .widget<TextFormField>(field('serviceNameField'))
            .controller!
            .text,
        'Netflix',
      );
      expect(
        tester.widget<TextFormField>(field('costField')).controller!.text,
        '9.99',
      );

      await enter(tester, 'serviceNameField', 'Netflix Ultra');
      await enter(tester, 'costField', '19.49');

      await tester.tap(find.text(l10n.pick));
      await tester.pumpAndSettle();
      final newDate = DateTime.now().add(const Duration(days: 60));
      await tester.tap(find.text('${newDate.day}').last);
      await tester.pumpAndSettle();
      final okLabel = MaterialLocalizations.of(
        tester.element(find.byType(CalendarDatePicker)),
      ).okButtonLabel;
      await tester.tap(find.text(okLabel));
      await tester.pumpAndSettle();

      await enter(tester, 'categoryField', 'Video');
      await enter(tester, 'urlField', 'https://netflix.com/manage');

      await tester.tap(find.text(l10n.saveChanges));
      await tester.pumpAndSettle();

      final updated = subsRepo.getAll().single;
      expect(updated.serviceName, 'Netflix Ultra');
      expect(updated.cost, 19.49);
      expect(updated.category, 'Video');
      expect(updated.cancellationUrl, 'https://netflix.com/manage');
      expect(updated.notes, 'HD');

      verify(() => notification.cancelForSubscription(existing.id)).called(1);
      verify(() => notification.scheduleRenewalReminder(
            subscriptionId: existing.id,
            title: any(named: 'title'),
            body: any(named: 'body'),
            renewalDate: any(named: 'renewalDate'),
            leadDays: 4,
            notifyHour: 8,
            notifyMinute: 15,
          )).called(1);
    });
  });
}
