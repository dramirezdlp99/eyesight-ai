import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/risk_zone.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';
import 'package:eyesight_ai/domain/usecases/zone_registration_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  const policy = ZoneRegistrationPolicy();

  ZoneRegistration auto(
    String label, {
    Proximity proximity = Proximity.near,
    bool hasPosition = true,
    double accuracy = 5,
    List<RiskZone> zones = const [],
    DateTime? now,
    bool enabled = true,
  }) =>
      policy.evaluateDetection(
        detection: det(label, proximity: proximity),
        position: hasPosition ? pos(accuracy: accuracy) : null,
        zones: zones,
        radiusM: 20,
        now: now ?? t0,
        newId: sequentialIds(),
        enabled: enabled,
      );

  group('registro automático (HU06)', () {
    test(
        'obstáculo fijo peligroso y cercano crea una zona con la posición del momento',
        () {
      final r = auto('pothole');
      expect(r, isA<ZoneCreated>());
      final z = (r as ZoneCreated).zone;
      expect(z.id, 'id1');
      expect(z.type, 'pothole');
      expect(z.lat, pastoLat);
      expect(z.lng, pastoLng);
      expect(z.origin, ZoneOrigin.automatic);
      expect(z.radiusM, 20);
      expect(z.count, 1);
    });

    test('las cinco clases fijas peligrosas crean zona (CA1)', () {
      for (final label in [
        'pothole',
        'step',
        'pole',
        'bollard',
        'construction'
      ]) {
        expect(auto(label), isA<ZoneCreated>(), reason: label);
      }
    });

    test('obstáculos móviles no crean zona (CA3)', () {
      for (final label in ['person', 'car', 'motorcycle', 'bicycle', 'bus']) {
        final r = auto(label);
        expect((r as ZoneSkipped).reason, ZoneSkipReason.notFixedHazard,
            reason: label);
      }
    });

    test('solo se registra si el obstáculo está cerca', () {
      expect((auto('pole', proximity: Proximity.medium) as ZoneSkipped).reason,
          ZoneSkipReason.notNear);
    });

    test('sin GPS no se registra (CA4)', () {
      expect((auto('pole', hasPosition: false) as ZoneSkipped).reason,
          ZoneSkipReason.noPosition);
    });

    test('con precisión peor que 20 m no se registra (CA1)', () {
      expect((auto('pole', accuracy: 25) as ZoneSkipped).reason,
          ZoneSkipReason.lowAccuracy);
      expect(auto('pole', accuracy: 20), isA<ZoneCreated>());
    });

    test('desactivado en los ajustes no registra', () {
      expect((auto('pole', enabled: false) as ZoneSkipped).reason,
          ZoneSkipReason.disabled);
    });

    test('mismo tipo a 10 m o menos incrementa el contador (CA2)', () {
      final existing = zone(lat: pastoLat + metersToLat(8), lastSeen: t0);
      final r = auto('pothole',
          zones: [existing], now: t0.add(const Duration(minutes: 5)));
      final z = (r as ZoneIncremented).zone;
      expect(z.id, existing.id);
      expect(z.count, 2);
      expect(z.lastSeenAt, t0.add(const Duration(minutes: 5)));
    });

    test('mismo tipo a más de 10 m crea otra zona', () {
      final existing = zone(lat: pastoLat + metersToLat(12));
      expect(auto('pothole', zones: [existing]), isA<ZoneCreated>());
    });

    test('otro tipo en el mismo lugar crea otra zona', () {
      expect(auto('pole', zones: [zone(type: 'pothole')]), isA<ZoneCreated>());
    });

    test('el mismo paso no se cuenta dos veces en menos de 60 s', () {
      final existing = zone(lastSeen: t0);
      final r = auto('pothole',
          zones: [existing], now: t0.add(const Duration(seconds: 30)));
      expect((r as ZoneSkipped).reason, ZoneSkipReason.alreadyCounted);
    });

    test('las etiquetas se normalizan a minúsculas', () {
      final r = auto('POTHOLE');
      expect((r as ZoneCreated).zone.type, 'pothole');
    });
  });

  group('registro manual (HU07)', () {
    test('crea una zona de origen manual', () {
      final r = policy.evaluateManual(
        type: 'step',
        position: pos(),
        zones: const [],
        radiusM: 20,
        now: t0,
        newId: sequentialIds('m'),
      );
      final z = (r as ZoneCreated).zone;
      expect(z.origin, ZoneOrigin.manual);
      expect(z.type, 'step');
      expect(z.id, 'm1');
    });

    test('sin GPS informa que no fue posible registrarla (CA4)', () {
      final r = policy.evaluateManual(
        type: 'other',
        position: null,
        zones: const [],
        radiusM: 20,
        now: t0,
        newId: sequentialIds(),
      );
      expect((r as ZoneSkipped).reason, ZoneSkipReason.noPosition);
    });

    test('sobre una zona existente del mismo tipo suma un encuentro', () {
      final r = policy.evaluateManual(
        type: 'pothole',
        position: pos(),
        zones: [zone(lastSeen: t0)],
        radiusM: 20,
        now: t0.add(const Duration(seconds: 5)),
        newId: sequentialIds(),
      );
      expect((r as ZoneIncremented).zone.count, 2);
    });
  });
}
