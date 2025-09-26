import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/presentation/screens/settings_screen.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';

import '../support/test_doubles.dart';
import '../support/widget_harness.dart';

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      null;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async =>
      null;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async =>
      null;

  @override
  Future<bool?> clearTemporaryFiles() async => false;
}

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

  group('SettingsScreen', () {
    FilePicker? originalPicker;

    setUp(() {
      try {
        originalPicker = FilePicker.platform;
      } catch (_) {
        originalPicker = null;
      }

      FilePicker.platform = _FakeFilePicker();
    });

    tearDown(() {
      if (originalPicker != null) {
        FilePicker.platform = originalPicker!;
      }
    });

    testWidgets('renders initial state from view model', (tester) async {
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
        home: const SettingsScreen(),
        providers: [
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVm),
          ChangeNotifierProvider<SubscriptionListViewModel>.value(
              value: listVm),
        ],
      );

      final currencyField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(currencyField.controller!.text, 'EUR');

      final themeDropdownState = tester.state<FormFieldState<String>>(
        find.byKey(const Key('themeModeDropdown')),
      );
      expect(themeDropdownState.value, 'system');

      final localeDropdownState = tester.state<FormFieldState<String>>(
        find.byKey(const Key('localeDropdown')),
      );
      expect(localeDropdownState.value, 'lv');
    });

    testWidgets('save persists changes via view model', (tester) async {
      final notification = stubNotificationService();
      final rescheduler = RecordingRescheduler();
      final subsRepo = FakeSubscriptionRepository();
      final settingsRepo =
          FakeSettingsRepository(const AppSettings(defaultCurrency: 'EUR'));

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
        home: const SettingsScreen(),
        providers: [
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVm),
          ChangeNotifierProvider<SubscriptionListViewModel>.value(
              value: listVm),
        ],
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'usd',
      );

      await tester.tap(find.byKey(const Key('themeModeDropdown')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.themeModeDark));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('localeDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.languageEnglish));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, '6');

      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      final updated = settingsRepo.current;
      expect(updated.defaultCurrency, 'USD');
      expect(updated.leadDays, 6);
      expect(updated.themeMode, 'dark');
      expect(updated.localeCode, 'en');
      expect(rescheduler.callCount, greaterThan(0));
    });
  });
}
