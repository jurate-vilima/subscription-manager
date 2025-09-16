import 'package:intl/intl.dart';

class Formatters {
  static String money(double amount, String currencyCode, {String? locale}) {
    final format = NumberFormat.currency(
      locale: locale ?? Intl.getCurrentLocale(),
      name: currencyCode,
    );
    return format.format(amount);
  }

  static String dateShort(DateTime d) {
    return DateFormat.yMMMd().format(d.toLocal());
  }
}
