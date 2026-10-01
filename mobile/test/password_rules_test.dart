import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/features/auth/data/password_rules.dart';

void main() {
  test('Miner1 is valid', () => expect(PasswordRules.evaluate('Miner1').isValid, true));
  test('too short / long', () {
    expect(PasswordRules.evaluate('Ab1').length, false);
    expect(PasswordRules.evaluate('Abcde12').length, false);
  });
  test('needs letter and digit', () {
    expect(PasswordRules.evaluate('123456').hasLetter, false);
    expect(PasswordRules.evaluate('abcdef').hasDigit, false);
  });
  test('no whitespace', () => expect(PasswordRules.evaluate('Ab 123').noSpaces, false));
  test('first error message', () {
    expect(PasswordRules.evaluate('').firstError, 'Password must be exactly 6 characters');
    expect(PasswordRules.evaluate('abcdef').firstError, 'Include at least one digit');
  });
}
