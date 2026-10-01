import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/features/auth/data/countries.dart';
import 'package:mine_guardian/features/auth/data/phone_validator.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

void main() {
  test('no country code', () => expect(validatePhone(null, '9876500101').error, 'Select your country code'));
  test('empty', () => expect(validatePhone('IN', '  ').error, 'Enter your mobile number'));
  test('letters', () => expect(validatePhone('IN', '98ab').error, 'Digits only'));
  test('leading zero', () => expect(validatePhone('IN', '09876500101').error, contains("Don't start with 0")));
  test('India 9 digits', () => expect(validatePhone('IN', '987650010').error, contains('10 digits')));
  test('India starting with 5', () => expect(validatePhone('IN', '5876500101').error, contains('start with 6, 7, 8 or 9')));
  test('valid India', () {
    final r = validatePhone('IN', '9876500101');
    expect(r.isValid, true);
    expect(r.e164, '+919876500101');
    expect(r.formatted, '98765 00101');
  });
  test('valid UK mobile', () {
    final r = validatePhone('GB', '7400 123456');
    expect(r.isValid, true);
    expect(r.e164, '+447400123456');
  });
  test('invalid UK number', () => expect(validatePhone('GB', '1234').isValid, false));

  test('every country code exists in phone_numbers_parser IsoCode', () {
    final names = IsoCode.values.map((e) => e.name).toSet();
    final missing = countries.where((c) => !names.contains(c.isoCode)).map((c) => c.isoCode).toList();
    expect(missing, isEmpty);
  });
  test('no duplicate iso codes', () {
    final isos = countries.map((c) => c.isoCode).toList();
    expect(isos.toSet().length, isos.length);
  });
  test('flag emoji computed', () => expect(countryByIso('IN')!.flag, '🇮🇳'));
}
