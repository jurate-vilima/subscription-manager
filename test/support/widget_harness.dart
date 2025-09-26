import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:subscription_manager/l10n/app_localizations.dart';

Future<void> pumpWidgetHarness(
  WidgetTester tester, {
  Widget? home,
  GoRouter? router,
  List<SingleChildWidget> providers = const [],
}) async {
  assert((home != null) ^ (router != null),
      'Provide either a home widget or a router');

  Widget app;
  if (router != null) {
    app = MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  } else {
    app = MaterialApp(
      home: home,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: app,
    ),
  );

  await tester.pump();
}
