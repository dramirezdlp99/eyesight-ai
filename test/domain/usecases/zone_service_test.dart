import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/zone_audit_entry.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';
import 'package:eyesight_ai/domain/usecases/purge_old_history.dart';
import 'package:eyesight_ai/domain/usecases/zone_registration_policy.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/fakes.dart';

void main() {
  late InMemoryZoneRepository zones;
  late InMemoryAuditRepository audit;
  late DateTime now;
  late ZoneService service;
  const settings = AppSettings();

  setUp(() {
    zones = InMemoryZoneRepository();
    audit = InMemoryAuditRepository();
    now = t0;
    service = ZoneService(
      zones: zones,
      audit: audit,
      clock: () => now,
      newId: sequentialIds('z'),
    );
  });

  group('registro (HU06 y HU07)', () {
    test('una detección de hueco cercano crea la zona y la audita', () async {
      final r =
          await service.registerDetection(det('pothole'), pos(), settings);
      expect(r, isA<ZoneCreated>());
      expect(zones.zones['z1']!.origin, ZoneOrigin.automatic);
      expect(audit.entries.single.action, AuditAction.created);
    });

    test('pasar de nuevo después de 60 s incrementa el contador', () async {
      await service.registerDetection(det('pothole'), pos(), settings);
      now = now.add(const Duration(minutes: 2));
      final r =
          await service.registerDetection(det('pothole'), pos(), settings);
      expect(r, isA<ZoneIncremented>());
      expect(zones.zones['z1']!.count, 2);
      expect(audit.entries.last.action, AuditAction.incremented);
    });

    test('con el registro automático desactivado no guarda nada', () async {
      final r = await service.registerDetection(
        det('pothole'),
        pos(),
        settings.copyWith(autoZones: false),
      );
      expect((r as ZoneSkipped).reason, ZoneSkipReason.disabled);
      expect(zones.zones, isEmpty);
      expect(audit.entries, isEmpty);
    });

    test('el radio de la zona nueva es el de los ajustes', () async {
      await service.registerManual(
          'step', pos(), settings.copyWith(alertRadiusM: 35));
      expect(zones.zones['z1']!.radiusM, 35);
      expect(zones.zones['z1']!.origin, ZoneOrigin.manual);
    });

    test('un obstáculo móvil no crea zona', () async {
      await service.registerDetection(
          det('person', proximity: Proximity.near), pos(), settings);
      expect(zones.zones, isEmpty);
    });
  });

  group('edición y eliminación (HU11)', () {
    setUp(() async {
      await service.registerManual('pothole', pos(), settings);
    });

    test('edita tipo, radio y nota saneada', () async {
      final error = await service.edit('z1',
          type: 'step', radiusM: 40, note: '  Frente\na la tienda ');
      expect(error, isNull);
      final z = zones.zones['z1']!;
      expect(z.type, 'step');
      expect(z.radiusM, 40);
      expect(z.note, 'Frente a la tienda');
      expect(audit.entries.last.action, AuditAction.edited);
    });

    test('rechaza radio fuera de rango, nota larga y tipo inválido (CA2)',
        () async {
      expect(await service.edit('z1', radiusM: 3), isNotNull);
      expect(await service.edit('z1', radiusM: 150), isNotNull);
      expect(await service.edit('z1', note: 'x' * 101), isNotNull);
      expect(await service.edit('z1', type: 'person'), isNotNull);
      expect(zones.zones['z1']!.radiusM, 20);
    });

    test('una zona inexistente informa el error', () async {
      expect(await service.edit('nada', radiusM: 30), 'La zona ya no existe.');
    });

    test('eliminar borra la zona y lo registra (CA3, CA4)', () async {
      expect(await service.delete('z1'), isTrue);
      expect(zones.zones, isEmpty);
      expect(audit.entries.last.action, AuditAction.deleted);
      expect(await service.delete('z1'), isFalse);
    });
  });

  test('randomId genera 32 caracteres hexadecimales distintos', () {
    final a = ZoneService.randomId();
    final b = ZoneService.randomId();
    expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(a, isNot(b));
  });

  test('PurgeOldHistory usa el corte de 90 días (HU12, CA4)', () async {
    final history = InMemoryHistoryRepository();
    await PurgeOldHistory(history)(t0);
    expect(history.lastCutoff, t0.subtract(const Duration(days: 90)));
  });
}
