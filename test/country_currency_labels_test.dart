import 'package:flutter_test/flutter_test.dart';
import 'package:woosh/utils/country_currency_labels.dart';
import 'package:woosh/models/price_option_model.dart';

void main() {
  group('CountryCurrencyLabels', () {
    test('should return correct currency info for Kenya (countryId: 1)', () {
      final currency = CountryCurrencyLabels.getCurrencyInfo(1);
      expect(currency['symbol'], equals('KES'));
      expect(currency['position'], equals('before'));
      expect(currency['decimalPlaces'], equals(2));
      expect(currency['name'], equals('Kenyan Shilling'));
    });

    test('should return correct currency info for Tanzania (countryId: 2)', () {
      final currency = CountryCurrencyLabels.getCurrencyInfo(2);
      expect(currency['symbol'], equals('TZS'));
      expect(currency['position'], equals('after'));
      expect(currency['decimalPlaces'], equals(0));
      expect(currency['name'], equals('Tanzania Shilling'));
    });

    test('should return correct currency info for Nigeria (countryId: 3)', () {
      final currency = CountryCurrencyLabels.getCurrencyInfo(3);
      expect(currency['symbol'], equals('₦'));
      expect(currency['position'], equals('before'));
      expect(currency['decimalPlaces'], equals(2));
      expect(currency['name'], equals('Nigerian Naira'));
    });

    test('should return default currency info for unknown country', () {
      final currency = CountryCurrencyLabels.getCurrencyInfo(999);
      expect(currency['symbol'], equals('KES'));
      expect(currency['position'], equals('before'));
      expect(currency['decimalPlaces'], equals(2));
      expect(currency['name'], equals('Kenyan Shilling'));
    });

    test('should return default currency info for null country', () {
      final currency = CountryCurrencyLabels.getCurrencyInfo(null);
      expect(currency['symbol'], equals('KES'));
      expect(currency['position'], equals('before'));
      expect(currency['decimalPlaces'], equals(2));
      expect(currency['name'], equals('Kenyan Shilling'));
    });

    test('should format currency correctly for Kenya (before position)', () {
      expect(CountryCurrencyLabels.formatCurrency(1000.50, 1),
          equals('KES 1000.50'));
      expect(CountryCurrencyLabels.formatCurrency(0, 1), equals('KES 0.00'));
      expect(CountryCurrencyLabels.formatCurrency(null, 1), equals('KES 0.00'));
    });

    test(
        'should format currency correctly for Tanzania (after position, no decimals)',
        () {
      expect(
          CountryCurrencyLabels.formatCurrency(1000.50, 2), equals('1001 TZS'));
      expect(CountryCurrencyLabels.formatCurrency(0, 2), equals('0 TZS'));
      expect(CountryCurrencyLabels.formatCurrency(null, 2), equals('TZS 0.00'));
    });

    test('should format currency correctly for Nigeria (before position)', () {
      expect(CountryCurrencyLabels.formatCurrency(1000.50, 3),
          equals('₦ 1000.50'));
      expect(CountryCurrencyLabels.formatCurrency(0, 3), equals('₦ 0.00'));
      expect(CountryCurrencyLabels.formatCurrency(null, 3), equals('₦ 0.00'));
    });

    test('should handle null amount gracefully', () {
      expect(CountryCurrencyLabels.formatCurrency(null, 1), equals('KES 0.00'));
      expect(CountryCurrencyLabels.formatCurrency(null, 2), equals('TZS 0.00'));
      expect(CountryCurrencyLabels.formatCurrency(null, 3), equals('₦ 0.00'));
      expect(
          CountryCurrencyLabels.formatCurrency(null, null), equals('KES 0.00'));
    });

    test('should return all currencies', () {
      final currencies = CountryCurrencyLabels.getAllCurrencies();
      expect(currencies.length, equals(3));
      expect(currencies.containsKey(1), isTrue);
      expect(currencies.containsKey(2), isTrue);
      expect(currencies.containsKey(3), isTrue);
    });

    test('should return correct currency symbol', () {
      expect(CountryCurrencyLabels.getCurrencySymbol(1), equals('KES'));
      expect(CountryCurrencyLabels.getCurrencySymbol(2), equals('TZS'));
      expect(CountryCurrencyLabels.getCurrencySymbol(3), equals('₦'));
      expect(CountryCurrencyLabels.getCurrencySymbol(null), equals('KES'));
    });

    test('should return correct currency name', () {
      expect(
          CountryCurrencyLabels.getCurrencyName(1), equals('Kenyan Shilling'));
      expect(CountryCurrencyLabels.getCurrencyName(2),
          equals('Tanzania Shilling'));
      expect(
          CountryCurrencyLabels.getCurrencyName(3), equals('Nigerian Naira'));
      expect(CountryCurrencyLabels.getCurrencyName(null),
          equals('Kenyan Shilling'));
    });

    test('should return unmodifiable map for getAllCurrencies', () {
      final currencies = CountryCurrencyLabels.getAllCurrencies();
      expect(() => currencies[1] = {'symbol': 'TEST'},
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('PriceOption Model', () {
    test('should parse value field correctly when it comes as string from API',
        () {
      final json = {
        'id': 5,
        'option': 'option 1',
        'value': '22000', // String value from API
        'value_tzs': '22000', // String value from API
        'value_ngn': null,
        'categoryId': 3,
      };

      final priceOption = PriceOption.fromJson(json);

      expect(priceOption.id, equals(5));
      expect(priceOption.option, equals('option 1'));
      expect(priceOption.value, equals(22000)); // Should be parsed as int
      expect(
          priceOption.value_tzs, equals(22000.0)); // Should be parsed as double
      expect(priceOption.value_ngn, isNull);
      expect(priceOption.categoryId, equals(3));
    });

    test('should parse value field correctly when it comes as int from API',
        () {
      final json = {
        'id': 6,
        'option': 'option 2',
        'value': 24000, // Int value from API
        'value_tzs': 24000.0, // Double value from API
        'value_ngn': 500.0, // Double value from API
        'categoryId': 3,
      };

      final priceOption = PriceOption.fromJson(json);

      expect(priceOption.id, equals(6));
      expect(priceOption.option, equals('option 2'));
      expect(priceOption.value, equals(24000));
      expect(priceOption.value_tzs, equals(24000.0));
      expect(priceOption.value_ngn, equals(500.0));
      expect(priceOption.categoryId, equals(3));
    });

    test('should handle null values gracefully', () {
      final json = {
        'id': 7,
        'option': 'option 3',
        'value': null,
        'value_tzs': null,
        'value_ngn': null,
        'categoryId': 3,
      };

      final priceOption = PriceOption.fromJson(json);

      expect(priceOption.id, equals(7));
      expect(priceOption.option, equals('option 3'));
      expect(priceOption.value, isNull);
      expect(priceOption.value_tzs, isNull);
      expect(priceOption.value_ngn, isNull);
      expect(priceOption.categoryId, equals(3));
    });
  });
}
