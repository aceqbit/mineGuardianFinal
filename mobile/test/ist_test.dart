import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/core/time/ist.dart';

void main() {
  test('toIst adds 5h30', () {
    final t = DateTime.utc(2026, 1, 1, 0, 0);
    expect(formatIst(t), '05:30');
  });
  test('shift windows incl. C across midnight', () {
    DateTime w(int h, int m) => DateTime.utc(2026, 1, 1, h, m);
    expect(isShiftOpen(Shift.b, w(15, 0)), true);
    expect(isShiftOpen(Shift.b, w(22, 0)), false);
    expect(isShiftOpen(Shift.c, w(22, 30)), true);
    expect(isShiftOpen(Shift.c, w(5, 30)), true);
    expect(isShiftOpen(Shift.c, w(14, 0)), false);
  });
  test('same IST day crosses UTC midnight', () {
    expect(sameIstDay(DateTime.utc(2026, 1, 1, 20, 0), DateTime.utc(2026, 1, 2, 1, 0)), true);
  });
}
