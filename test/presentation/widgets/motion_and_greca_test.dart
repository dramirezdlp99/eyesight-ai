import 'package:eyesight_ai/presentation/widgets/greca.dart';
import 'package:eyesight_ai/presentation/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envuelve [child] con «Quitar animaciones» activado o no.
Widget host(Widget child, {bool reduce = false}) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  group('animaciones en bucle', () {
    final loops = <String, Widget>{
      'PulseDots': const PulseDots(count: 3, color: Colors.red),
      'ScanSweep': const SizedBox(width: 200, height: 200, child: ScanSweep()),
      'RadarRings': const RadarRings(color: Colors.amber, child: Text('!')),
      'WaveBars': const WaveBars(color: Colors.blue),
    };
    for (final entry in loops.entries) {
      testWidgets('${entry.key} se mueve y se detiene sin animaciones',
          (tester) async {
        await tester.pumpWidget(host(entry.value));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.hasRunningAnimations, isTrue);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(host(entry.value, reduce: true));
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('PulseDots dibuja un punto por cada pulso', (tester) async {
      await tester.pumpWidget(
        host(const PulseDots(count: 2, color: Colors.red), reduce: true),
      );
      expect(
        find.descendant(
          of: find.byType(PulseDots),
          matching: find.byType(Container),
        ),
        findsNWidgets(2),
      );
    });
  });

  testWidgets('CountdownRing cuenta los 8 segundos de la respuesta',
      (tester) async {
    await tester.pumpWidget(
      host(
        const CountdownRing(
          duration: Duration(seconds: 8),
          color: Colors.blue,
        ),
      ),
    );
    expect(find.text('8'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.text('5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
      'StaggeredEntrance muestra todo y TalkBack lo lee desde el '
      'primer cuadro', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const StaggeredEntrance(children: [Text('Uno'), Text('Dos')])),
    );
    expect(find.bySemanticsLabel('Dos'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Dos'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1);
    semantics.dispose();
  });

  group('greca', () {
    testWidgets('la banda es decorativa y no se anuncia', (tester) async {
      await tester.pumpWidget(host(const GrecaBand(animate: true)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.descendant(
          of: find.byType(GrecaBand),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la esquina se dibuja arriba y abajo', (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GrecaCorner(color: Colors.blue, accent: Colors.amber),
              GrecaCorner(color: Colors.blue, bottom: true),
            ],
          ),
        ),
      );
      expect(
          tester.getSize(find.byType(GrecaCorner).first), const Size(150, 110));
      expect(tester.takeException(), isNull);
    });

    test('el desplazamiento cambia el dibujo', () {
      const a = GrecaPainter();
      const b = GrecaPainter(offset: 10);
      expect(a.shouldRepaint(a), isFalse);
      expect(a.shouldRepaint(b), isTrue);
    });
  });
}
