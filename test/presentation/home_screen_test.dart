import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/presentation/screens/home_screen.dart';
import 'package:subscription_manager/utils/calc.dart';
import 'package:subscription_manager/utils/formatters.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';

import '../support/test_doubles.dart';
import '../support/widget_harness.dart';

GoRouter _buildRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/add',
          builder: (context, state) => const Scaffold(body: Text('Add Screen')),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('Settings Screen')),
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      Subscription(
        id: 'fallback',
        serviceName: 'Fallback',
        cost: 1,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 1, 1),
      ),
    );
  });

  group('HomeScreen', () {
    testWidgets('shows empty state when no subscriptions exist',
        (tester) async {
      final notification = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(const AppSettings());
      final listVm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notification,
        rescheduler: rescheduler.call,
      );
      await listVm.load();

      final settingsVm = SettingsViewModel(
        settingsRepo: settingsRepo,
        subscriptionRepo: subsRepo,
        rescheduler: rescheduler.call,
      );

      await pumpWidgetHarness(
        tester,
        router: _buildRouter(),
        providers: [
          ChangeNotifierProvider<SubscriptionListViewModel>.value(
              value: listVm),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVm),
        ],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.noSubscriptionsYet), findsOneWidget);
      expect(find.text(l10n.addFirstSubscription), findsOneWidget);
    });

    testWidgets('renders totals summary and currency mismatch banner',
        (tester) async {
      final notification = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(
        TestFactory.settings(
          currency: 'EUR',
          localeCode: 'en',
        ),
      );

      final anchor = DateTime(2025, 1, 1);
      await subsRepo.addAll([
        TestFactory.sub(
          id: 'netflix',
          name: 'Netflix',
          cost: 10,
          currency: 'EUR',
          cycle: BillingCycle.monthly,
          next: anchor,
        ),
        TestFactory.sub(
          id: 'prime',
          name: 'Prime',
          cost: 120,
          currency: 'EUR',
          cycle: BillingCycle.yearly,
          next: anchor.add(const Duration(days: 15)),
        ),
        TestFactory.sub(
          id: 'hulu',
          name: 'Hulu',
          cost: 5,
          currency: 'USD',
          cycle: BillingCycle.monthly,
          next: anchor.add(const Duration(days: 5)),
        ),
      ]);

      final listVm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notification,
        rescheduler: rescheduler.call,
      );
      await listVm.load();

      final settingsVm = SettingsViewModel(
        settingsRepo: settingsRepo,
        subscriptionRepo: subsRepo,
        rescheduler: rescheduler.call,
      );

      await pumpWidgetHarness(
        tester,
        router: _buildRouter(),
        providers: [
          ChangeNotifierProvider<SubscriptionListViewModel>.value(
              value: listVm),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVm),
        ],
      );
      await tester.pumpAndSettle();

      final screenContext = tester.element(find.byType(HomeScreen));
      final l10n = AppLocalizations.of(screenContext)!;
      final monthlyText = l10n.monthlyTotal(
        Formatters.money(
          totalMonthly(listVm.items),
          settingsRepo.current.defaultCurrency,
          locale: settingsRepo.current.localeCode,
        ),
      );
      final yearlyText = l10n.yearlyTotal(
        Formatters.money(
          totalYearly(listVm.items),
          settingsRepo.current.defaultCurrency,
          locale: settingsRepo.current.localeCode,
        ),
      );

      expect(find.text(monthlyText), findsOneWidget);
      expect(find.text(yearlyText), findsOneWidget);
      expect(find.text(l10n.currenciesDiffer), findsOneWidget);
    });

    testWidgets('renders subscription list and allows delete with undo',
        (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(1200, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });
      final notification = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(const AppSettings());

      final existing = Subscription(
        id: 'netflix',
        serviceName: 'Netflix',
        cost: 9.99,
        currency: 'EUR',
        billingCycle: BillingCycle.monthly,
        nextRenewalDate: DateTime(2025, 5, 20),
      );
      await subsRepo.add(existing);

      final listVm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notification,
        rescheduler: rescheduler.call,
      );
      await listVm.load();

      final settingsVm = SettingsViewModel(
        settingsRepo: settingsRepo,
        subscriptionRepo: subsRepo,
        rescheduler: rescheduler.call,
      );

      await pumpWidgetHarness(
        tester,
        router: _buildRouter(),
        providers: [
          ChangeNotifierProvider<SubscriptionListViewModel>.value(
              value: listVm),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVm),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('netflix')), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(subsRepo.getAll(), isEmpty);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.deletedSubscription('Netflix')), findsOneWidget);

      final actionFinder = find.byType(SnackBarAction);
      expect(actionFinder, findsOneWidget);
      final action = tester.widget<SnackBarAction>(actionFinder);
      action.onPressed();
      await tester.pump();

      expect(subsRepo.getAll(), isNotEmpty);
    });

    testWidgets('tapping FAB navigates to add screen', (tester) async {
      final notification = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo = FakeSettingsRepository(const AppSettings());
      final listVm = SubscriptionListViewModel(
        repo: subsRepo,
        settingsRepo: settingsRepo,
        notificationService: notification,
        rescheduler: rescheduler.call,
      );
      await listVm.load();

      final settingsVm = SettingsViewModel(
        settingsRepo: settingsRepo,
        subscriptionRepo: subsRepo,
        rescheduler: rescheduler.call,
      );

      await pumpWidgetHarness(
        tester,
        router: _buildRouter(),
        providers: [
          ChangeNotifierProvider<SubscriptionListViewModel>.value(
              value: listVm),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVm),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add Screen'), findsOneWidget);
    });
  });
}
