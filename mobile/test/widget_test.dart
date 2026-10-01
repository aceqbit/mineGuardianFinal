import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/core/auth/phone_identity.dart';

void main() {
  test('loginEmailFor builds the hidden login email', () {
    expect(loginEmailFor('+919876500101'), '919876500101@phone.mineguardian.app');
  });

  test('enums round-trip and throw on unknown', () {
    expect(Role.fromWire('miner'), Role.miner);
    expect(PpeKey.fromWire('HELMET'), PpeKey.helmet);
    expect(() => Role.fromWire('boss'), throwsArgumentError);
  });
}
