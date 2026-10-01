/// Firebase's phone provider is OTP-only, so a phone number maps to a hidden login email.
/// Users only ever see the phone number and password.
const String loginEmailDomain = 'phone.mineguardian.app';

/// `+919876500101` -> `919876500101@phone.mineguardian.app`
String loginEmailFor(String e164) {
  final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
  return '$digits@$loginEmailDomain';
}
