import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:subscription_manager/utils/formatters.dart';

void main() {
  setUp(() {
    Intl.defaultLocale = 'en_US';
  });

  test('money formats currency according to locale', () {
    final usd = Formatters.money(12.345, 'USD', locale: 'en_US');
    expect(usd, 'USD12.35');

    final eur = Formatters.money(987.6, 'EUR', locale: 'de_DE');
    expect(eur, '987,60\u00A0EUR');
  });

  test('dateShort uses local representation', () {
    final result = Formatters.dateShort(DateTime(2025, 5, 10));
    expect(result, 'May 10, 2025');
  });
}
