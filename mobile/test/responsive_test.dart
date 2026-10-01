import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/responsive.dart';

void main() {
  test('adaptiveColumns clamps between 1 and 4', () {
    expect(adaptiveColumns(100), 1);
    expect(adaptiveColumns(328), 1);
    expect(adaptiveColumns(768), 4);
    expect(adaptiveColumns(1280), 4);
    expect(adaptiveColumns(500), 2);
  });

  test('size classes', () {
    expect(sizeClassForWidth(599), SizeClass.compact);
    expect(sizeClassForWidth(600), SizeClass.medium);
    expect(sizeClassForWidth(1023), SizeClass.medium);
    expect(sizeClassForWidth(1024), SizeClass.expanded);
  });
}
