import 'package:flutter_test/flutter_test.dart';

import 'package:subscription_manager/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads AppLocalizations for each supported locale', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.appTitle, isNotEmpty, reason: locale.toLanguageTag());
      expect(l10n.settings, isNotEmpty, reason: 'settings ');
      expect(l10n.save, isNotEmpty, reason: 'save ');
    }
  });
}
