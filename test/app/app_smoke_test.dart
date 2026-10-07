import 'package:eyesight_ai/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la aplicación arranca y anuncia su nombre como encabezado',
      (tester) async {
    await tester.pumpWidget(const EyeSightApp());
    expect(find.text('EyeSight AI'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('EyeSight AI')),
         isSemantics(isHeader: true, label: 'EyeSight AI'),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
