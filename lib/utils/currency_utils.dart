import 'package:intl/intl.dart';
import '../models/price_option_model.dart';

class CurrencyUtils {
  static String format(double amount, {int? countryId}) {
    switch (countryId) {
      case 1: // Kenya
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: 'Ksh ',
          decimalDigits: 2,
        ).format(amount);
      case 2: // Tanzania
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: 'TZS ',
          decimalDigits: 2,
        ).format(amount);
      case 3: // Nigeria
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: 'NGN ',
          decimalDigits: 2,
        ).format(amount);
      default: // Default to Kenya
        return NumberFormat.currency(
          locale: 'en_US',
          symbol: 'Ksh ',
          decimalDigits: 2,
        ).format(amount);
    }
  }

  static double getPriceForCountry(PriceOption priceOption, int countryId) {
    switch (countryId) {
      case 1: // Kenya
        return priceOption.value ?? 0.0;
      case 2: // Tanzania
        return priceOption.valueTzs ?? 0.0;
      case 3: // Nigeria
        return priceOption.valueNgn ?? 0.0;
      default: // Default to Kenya
        return priceOption.value ?? 0.0;
    }
  }

  static String getCurrencySymbol(int countryId) {
    switch (countryId) {
      case 1: // Kenya
        return 'Ksh ';
      case 2: // Tanzania
        return 'TZS ';
      case 3: // Nigeria
        return 'NGN ';
      default: // Default to Kenya
        return 'Ksh ';
    }
  }
}
