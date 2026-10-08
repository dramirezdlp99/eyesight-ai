import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/presentation/widgets/detection_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  testWidgets('anuncia a TalkBack los obstáculos dibujados (RNF06)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 400,
          child: DetectionOverlay(detections: [det('pole')]),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Poste, cerca, al frente'), findsOneWidget);
  });

  testWidgets('sin detecciones informa que no hay obstáculos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DetectionOverlay(detections: [])),
    );
    expect(find.bySemanticsLabel('Sin obstáculos detectados'), findsOneWidget);
  });

  test('colores distintos por cercanía y repintado solo con datos nuevos', () {
    expect(DetectionPainter.colorFor(Proximity.near),
        isNot(DetectionPainter.colorFor(Proximity.far)));
    final list = [det('pole', box: const Rect.fromLTRB(0.1, 0.1, 0.2, 0.2))];
    expect(
        DetectionPainter(list).shouldRepaint(DetectionPainter(list)), isFalse);
    expect(DetectionPainter(list).shouldRepaint(DetectionPainter(const [])),
        isTrue);
  });
}
