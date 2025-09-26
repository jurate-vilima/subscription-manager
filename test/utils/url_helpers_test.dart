import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/utils/url_helpers.dart';

class FakeUrlLauncher extends UrlLauncherPlatform {
  FakeUrlLauncher({
    required this.canLaunchResult,
    this.launchResult = true,
    this.throwOnLaunch = false,
  });

  @override
  LinkDelegate? get linkDelegate => null;

  bool canLaunchResult;
  bool launchResult;
  bool throwOnLaunch;
  String? launchedUrl;
  int canLaunchCalls = 0;
  int launchCalls = 0;

  @override
  Future<bool> canLaunch(String url) async {
    canLaunchCalls++;
    return canLaunchResult;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchCalls++;
    launchedUrl = url;
    if (throwOnLaunch) {
      throw StateError('Launch failed');
    }
    return launchResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UrlHelpers.open', () {
    late FakeUrlLauncher launcher;

    setUp(() {
      launcher = FakeUrlLauncher(canLaunchResult: true);
      UrlLauncherPlatform.instance = launcher;
    });

    Future<void> pumpHarness(
      WidgetTester tester,
      void Function(BuildContext) onPressed,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => onPressed(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('does nothing for null or invalid URLs', (tester) async {
      await pumpHarness(tester, (context) => UrlHelpers.open(context, null));
      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(launcher.launchCalls, 0);

      await pumpHarness(
        tester,
        (context) => UrlHelpers.open(context, '   '),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(launcher.launchCalls, 0);
    });

    testWidgets('launches external application when available', (tester) async {
      await pumpHarness(
        tester,
        (context) => UrlHelpers.open(context, 'https://example.com'),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(launcher.canLaunchCalls, 1);
      expect(launcher.launchCalls, 1);
      expect(launcher.launchedUrl, 'https://example.com');
    });

    testWidgets('shows snackbar when cannot launch', (tester) async {
      launcher.canLaunchResult = false;
      await pumpHarness(
        tester,
        (context) => UrlHelpers.open(context, 'https://example.com'),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Could not open link'), findsOneWidget);
    });

    testWidgets('shows snackbar when launch throws', (tester) async {
      launcher.throwOnLaunch = true;
      await pumpHarness(
        tester,
        (context) => UrlHelpers.open(context, 'https://example.com'),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Could not open link'), findsOneWidget);
    });
  });
}
