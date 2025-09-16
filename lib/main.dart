import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';

import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/models/billing_cycle_adapter.dart';
import 'package:subscription_manager/models/app_settings.dart'; // <- your model

import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import 'package:subscription_manager/services/notification_service.dart';
import 'package:subscription_manager/services/cancellation_links_service.dart';
import 'package:subscription_manager/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage();
  const keyName = 'hiveKey';
  final storedKey = await secureStorage.read(key: keyName);
  List<int> encryptionKey;
  if (storedKey == null) {
    encryptionKey = Hive.generateSecureKey();
    await secureStorage.write(
      key: keyName,
      value: base64UrlEncode(encryptionKey),
    );
  } else {
    encryptionKey = base64Url.decode(storedKey);
  }

  await Hive.initFlutter();

  Hive
    ..registerAdapter(SubscriptionAdapter())
    ..registerAdapter(BillingCycleAdapter())
    ..registerAdapter(AppSettingsAdapter());

  await Hive.openBox<Subscription>(
    'subscriptions',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );
  await Hive.openBox<AppSettings>(
    'settings',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  // Ensure defaults
  final settingsBox = Hive.box<AppSettings>('settings');
  await settingsBox.put('app', settingsBox.get('app') ?? const AppSettings());

  final notificationService = NotificationService();
  String? pendingPayload;
  bool appStarted = false;
  notificationService.payloadStream.listen((payload) {
    if (appStarted) {
      appRouter.go('/edit/$payload');
    } else {
      pendingPayload = payload;
    }
  });
  await notificationService.init();
  await CancellationLinksService().load();

  final subscriptionListViewModel = SubscriptionListViewModel();
  await subscriptionListViewModel.load();

  runApp(
    SubscriptionManagerApp(
      subscriptionListViewModel: subscriptionListViewModel,
    ),
  );
  appStarted = true;
  if (pendingPayload != null) {
    appRouter.go('/edit/$pendingPayload');
  }
}

class SubscriptionManagerApp extends StatelessWidget {
  final SubscriptionListViewModel subscriptionListViewModel;

  const SubscriptionManagerApp({
    super.key,
    required this.subscriptionListViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ChangeNotifierProvider.value(value: subscriptionListViewModel),
      ],
      child: Builder(
        builder: (context) {
          final settingsViewModel = context.watch<SettingsViewModel>();
          final modeStr = settingsViewModel.state.themeMode;
          ThemeMode mode;
          switch (modeStr) {
            case 'light':
              mode = ThemeMode.light;
              break;
            case 'dark':
              mode = ThemeMode.dark;
              break;
            default:
              mode = ThemeMode.system;
          }

          return MaterialApp.router(
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)!.appTitle,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: mode,
            locale: Locale(settingsViewModel.state.localeCode),
            routerConfig: appRouter,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    );
  }
}
