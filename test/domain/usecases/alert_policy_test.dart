import 'dart:ui';

import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/usecases/alert_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  group('mensaje de voz (HU03, CA1)', () {
    test('obstáculo en la trayectoria', () {
      expect(AlertPolicy.messageFor(det('pole')), 'Poste, cerca, al frente');
      expect(
        AlertPolicy.messageFor(det('person', proximity: Proximity.medium)),
        'Persona, a media distancia, al frente',
      );
    });

    test('obstáculo cercano fuera de la trayectoria indica el lado', () {
      final left = det('bicycle',
          inPath: false, box: const Rect.fromLTRB(0.0, 0.5, 0.2, 0.95));
      final right = det('bicycle',
          inPath: false, box: const Rect.fromLTRB(0.8, 0.5, 1.0, 0.95));
      expect(AlertPolicy.messageFor(left), 'Bicicleta, cerca, a la izquierda');
      expect(AlertPolicy.messageFor(right), 'Bicicleta, cerca, a la derecha');
    });
  });

  test('patrones de vibración distintos por cercanía (HU04)', () {
    expect(HapticPatterns.forProximity(Proximity.near), HapticPatterns.near);
    expect(HapticPatterns.near.where((v) => v > 0).length,
        5); // 3 pulsos + 2 pausas
    expect(HapticPatterns.medium.length, 4);
    expect(HapticPatterns.far.length, 2);
    expect(HapticPatterns.zone[1], greaterThan(HapticPatterns.far[1]));
  });

  test('no anuncia obstáculos lejanos fuera de la trayectoria (HU03, CA4)', () {
    final p = AlertPolicy();
    expect(
      p.decide([det('car', inPath: false, proximity: Proximity.far)], t0),
      isNull,
    );
    expect(
      p.decide([det('car', inPath: false, proximity: Proximity.medium)], t0),
      isNull,
    );
  });

  test('anuncia primero el más cercano (HU03, CA3)', () {
    final p = AlertPolicy();
    final d = p.decide([
      det('person', proximity: Proximity.far),
      det('pole', proximity: Proximity.near),
      det('car', proximity: Proximity.medium),
    ], t0);
    expect(d!.detection.label, 'pole');
    expect(d.vibrationPattern, HapticPatterns.near);
  });

  test('no repite el mismo obstáculo antes de 4 s (HU03, CA2)', () {
    final p = AlertPolicy();
    final o = det('person', proximity: Proximity.medium);
    expect(p.decide([o], t0), isNotNull);
    expect(p.decide([o], t0.add(const Duration(seconds: 3))), isNull);
    expect(p.decide([o], t0.add(const Duration(seconds: 4))), isNotNull);
  });

  test('repite antes de 4 s si el obstáculo pasa a «cerca»', () {
    final p = AlertPolicy();
    p.decide([det('person', proximity: Proximity.medium)], t0);
    final d = p.decide(
      [det('person', proximity: Proximity.near)],
      t0.add(const Duration(seconds: 1)),
    );
    expect(d, isNotNull);
    expect(d!.message, 'Persona, cerca, al frente');
  });

  test('si el más urgente ya se anunció, pasa al siguiente', () {
    final p = AlertPolicy();
    p.decide([det('pole')], t0);
    final d = p.decide(
      [det('pole'), det('person', proximity: Proximity.medium)],
      t0.add(const Duration(seconds: 1)),
    );
    expect(d!.detection.label, 'person');
  });

  test('guarda la última alerta para «repetir» y reset la borra', () {
    final p = AlertPolicy();
    p.decide([det('pole')], t0);
    expect(p.lastDecision!.message, 'Poste, cerca, al frente');
    p.reset();
    expect(p.lastDecision, isNull);
  });
}
