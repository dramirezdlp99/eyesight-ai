import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/usecases/stability_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  test('confirma una clase solo tras 3 cuadros consecutivos (HU03, CA1)', () {
    final f = StabilityFilter();
    expect(f.update([det('pole')]), isEmpty);
    expect(f.update([det('pole')]), isEmpty);
    final third = f.update([det('pole')]);
    expect(third.single.label, 'pole');
    expect(f.accept(det('pole')), isTrue);
  });

  test('un cuadro sin la clase reinicia la cuenta', () {
    final f = StabilityFilter();
    f.update([det('pole')]);
    f.update([det('pole')]);
    f.update([]);
    expect(f.update([det('pole')]), isEmpty);
    expect(f.accept(det('pole')), isFalse);
  });

  test('conserva la detección más urgente de cada clase', () {
    final f = StabilityFilter(window: 1);
    final out = f.update([
      det('person', proximity: Proximity.far, confidence: 0.9),
      det('person', proximity: Proximity.near, confidence: 0.6),
      det('person', proximity: Proximity.near, confidence: 0.7),
    ]);
    expect(out.single.proximity, Proximity.near);
    expect(out.single.confidence, 0.7);
  });

  test('clases distintas se cuentan por separado', () {
    final f = StabilityFilter(window: 2);
    f.update([det('pole'), det('person')]);
    final out = f.update([det('pole')]);
    expect(out.map((d) => d.label), ['pole']);
  });

  test('reset borra el estado', () {
    final f = StabilityFilter(window: 1);
    f.update([det('car')]);
    f.reset();
    expect(f.accept(det('car')), isFalse);
  });
}
