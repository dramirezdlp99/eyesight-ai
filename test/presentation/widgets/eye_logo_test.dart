import 'package:eyesight_ai/presentation/widgets/eye_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el ojo está abierto casi todo el ciclo y parpadea al final', () {
    expect(EyePainter.opennessAt(0.1), 1);
    expect(EyePainter.opennessAt(0.5), 1);
    expect(EyePainter.opennessAt(0.91), lessThan(0.1));
    expect(EyePainter.opennessAt(0.99), 1);
  });

  testWidgets('se anuncia a TalkBack como EyeSight AI', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: EyeLogo())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel('EyeSight AI'), findsOneWidget);
  });

  testWidgets('con «Quitar animaciones» el ojo queda quieto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Center(child: EyeLogo()),
          ),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(EyeLogo), findsOneWidget);
  });

  testWidgets('cerrado (escáner detenido) no anima', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: EyeLogo(closed: true))),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('la mirada vuelve al frente al final del ciclo', () {
    expect(EyePainter.lookAt(0.2), 0);
    expect(EyePainter.lookAt(0.6), lessThan(0));
    expect(EyePainter.lookAt(1.0), closeTo(0, 0.01));
  });

  test('repinta solo si cambia algo', () {
    const a = EyePainter(
      openness: 1,
      pupilShift: 0,
      tile: Colors.blue,
      sclera: Colors.white,
      iris: Colors.amber,
      pupil: Colors.black,
    );
    const b = EyePainter(
      openness: 0.5,
      pupilShift: 0,
      tile: Colors.blue,
      sclera: Colors.white,
      iris: Colors.amber,
      pupil: Colors.black,
    );
    expect(a.shouldRepaint(a), isFalse);
    expect(a.shouldRepaint(b), isTrue);
  });
}
