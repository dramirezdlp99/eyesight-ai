import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Pantalla de un teléfono como el vivo Y22s (360 x 800 dp).
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
