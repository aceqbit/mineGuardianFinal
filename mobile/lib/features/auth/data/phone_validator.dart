import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'countries.dart';

class PhoneValidation {
  const PhoneValidation.ok({required this.e164, required this.formatted, required this.national})
      : error = null;
  const PhoneValidation.error(this.error)
      : e164 = null,
        formatted = null,
        national = null;

  final String? error;
  final String? e164;
  final String? formatted;
  final String? national;

  bool get isValid => error == null;
}

/// Validation order: (1) country, (2) empty, (3) digits only, (4) leading 0, (5) India rule,
/// (6) libphonenumber-style mobile validity, (7) ok.
PhoneValidation validatePhone(String? isoCode, String rawNational) {
  final country = countryByIso(isoCode);
  if (country == null) return const PhoneValidation.error('Select your country code');
  final trimmed = rawNational.trim();
  if (trimmed.isEmpty) return const PhoneValidation.error('Enter your mobile number');
  final digits = trimmed.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d+$').hasMatch(digits)) return const PhoneValidation.error('Digits only');
  if (digits.startsWith('0')) return const PhoneValidation.error("Don't start with 0 — enter the number without the leading 0");
  if (country.isoCode == 'IN' && !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
    return const PhoneValidation.error('Indian mobile numbers have 10 digits and start with 6, 7, 8 or 9');
  }
  final iso = IsoCode.values.where((i) => i.name == country.isoCode).firstOrNull;
  var valid = false;
  String? formatted;
  if (iso != null) {
    try {
      final p = PhoneNumber.parse('+${country.dialCode}$digits', destinationCountry: iso);
      valid = p.isValid(type: PhoneNumberType.mobile);
      if (valid) formatted = p.formatNsn(isoCode: iso);
    } catch (_) {
      valid = false;
    }
  }
  if (!valid) return PhoneValidation.error('Not a valid mobile number for ${country.name} (+${country.dialCode})');
  if (country.isoCode == 'IN') formatted = '${digits.substring(0, 5)} ${digits.substring(5)}';
  return PhoneValidation.ok(e164: '+${country.dialCode}$digits', formatted: formatted ?? digits, national: digits);
}
