import 'dart:ui';

import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/usecases/proximity_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  const estimator = ProximityEstimator();

  group('cercanía relativa (numeral 2.5.8)', () {
    test('caja que toca el borde inferior está cerca', () {
      expect(estimator.estimate(const Rect.fromLTRB(0.4, 0.7, 0.6, 0.95)),
          Proximity.near);
    });

    test('caja muy alta está cerca aunque no toque el borde', () {
      expect(estimator.estimate(const Rect.fromLTRB(0.4, 0.1, 0.6, 0.7)),
          Proximity.near);
    });

    test('caja en la mitad inferior está a media distancia', () {
      expect(estimator.estimate(const Rect.fromLTRB(0.4, 0.5, 0.6, 0.7)),
          Proximity.medium);
    });

    test('caja pequeña y alta en la imagen está lejos', () {
      expect(estimator.estimate(const Rect.fromLTRB(0.45, 0.3, 0.5, 0.45)),
          Proximity.far);
    });
  });

  group('franja de trayectoria', () {
    test('obstáculo centrado y en la parte inferior está en la trayectoria',
        () {
      expect(
          estimator.isInPath(const Rect.fromLTRB(0.4, 0.5, 0.6, 0.9)), isTrue);
    });

    test('obstáculo por encima de la franja no está en la trayectoria', () {
      expect(
          estimator.isInPath(const Rect.fromLTRB(0.4, 0.1, 0.6, 0.3)), isFalse);
    });

    test('obstáculo en el borde lateral no está en la trayectoria', () {
      expect(
          estimator.isInPath(const Rect.fromLTRB(0.0, 0.5, 0.2, 0.9)), isFalse);
      expect(estimator.isInPath(const Rect.fromLTRB(0.85, 0.5, 1.0, 0.9)),
          isFalse);
    });

    test('obstáculo ancho que cubre un tercio de la franja sí está', () {
      // Centro en 0,25 (fuera), pero 0,28–0,40 es 40 % de su ancho.
      expect(estimator.isInPath(const Rect.fromLTRB(0.10, 0.5, 0.40, 0.9)),
          isTrue);
    });
  });

  test('annotate completa cercanía y trayectoria', () {
    final d = estimator.annotate(
      det('pole',
          box: const Rect.fromLTRB(0.45, 0.4, 0.55, 0.92),
          proximity: Proximity.far,
          inPath: false),
    );
    expect(d.proximity, Proximity.near);
    expect(d.inPath, isTrue);
  });
}
