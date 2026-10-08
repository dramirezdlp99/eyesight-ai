import 'package:eyesight_ai/core/security/encrypted_storage.dart';
import 'package:eyesight_ai/data/repositories/audit_repository.dart';
import 'package:eyesight_ai/data/repositories/history_repository.dart';
import 'package:eyesight_ai/data/repositories/settings_repository.dart';
import 'package:eyesight_ai/data/repositories/zone_repository.dart';
import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/detection_record.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/domain/entities/zone_audit_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/hive_test_storage.dart';

void main() {
  late HiveTestStorage t;

  setUp(() async => t = await HiveTestStorage.open());
  tearDown(() async => t.dispose());

  group('ZoneRepository (Hive cifrado)', () {
    late ZoneRepository repo;
    setUp(
        () => repo = ZoneRepository(t.storage.box(EncryptedStorage.zonesBox)));

    test('guarda, lee, actualiza y elimina', () async {
      final z = zone(id: 'a');
      await repo.save(z);
      expect(await repo.byId('a'), z);
      expect(await repo.count(), 1);

      await repo.update(z.copyWith(count: 4, note: 'esquina'));
      expect((await repo.byId('a'))!.count, 4);

      await repo.delete('a');
      expect(await repo.byId('a'), isNull);
      expect(await repo.all(), isEmpty);
    });

    test('update de una zona inexistente falla', () async {
      await expectLater(repo.update(zone(id: 'x')), throwsStateError);
    });

    test('all ordena por fecha de creación y omite registros dañados (RNF05)',
        () async {
      await repo.save(zone(id: 'b', created: t0.add(const Duration(hours: 1))));
      await repo.save(zone(id: 'a', created: t0));
      await t.storage
          .box(EncryptedStorage.zonesBox)
          .put('roto', {'id': 'roto'});
      await t.storage.box(EncryptedStorage.zonesBox).put('texto', 'no es mapa');
      final all = await repo.all();
      expect(all.map((z) => z.id), ['a', 'b']);
    });

    test('los datos sobreviven al cerrar y reabrir con la misma clave',
        () async {
      await repo.save(zone(id: 'persistente'));
      await t.storage.close();
      final reopened = await HiveTestStorage.open(directory: t.directory);
      final again =
          ZoneRepository(reopened.storage.box(EncryptedStorage.zonesBox));
      expect((await again.byId('persistente'))!.type, 'pothole');
    });

    test('clear vacía la colección', () async {
      await repo.save(zone(id: 'a'));
      await repo.clear();
      expect(await repo.count(), 0);
    });
  });

  group('HistoryRepository (HU12)', () {
    late HistoryRepository repo;
    setUp(() =>
        repo = HistoryRepository(t.storage.box(EncryptedStorage.historyBox)));

    DetectionRecord rec(String label, Duration offset) => DetectionRecord(
          label: label,
          confidence: 0.8,
          proximity: Proximity.near,
          timestamp: t0.add(offset),
          lat: pastoLat,
          lng: pastoLng,
        );

    test('devuelve del más reciente al más antiguo (CA1)', () async {
      await repo.add(rec('pole', Duration.zero));
      await repo.add(rec('person', const Duration(minutes: 2)));
      await repo.add(rec('car', const Duration(minutes: 1)));
      final all = await repo.query();
      expect(all.map((r) => r.label), ['person', 'car', 'pole']);
    });

    test('filtra por rango de fechas y tipo (CA2)', () async {
      await repo.add(rec('pole', Duration.zero));
      await repo.add(rec('pole', const Duration(days: 2)));
      await repo.add(rec('person', const Duration(days: 2)));
      final r = await repo.query(
        from: t0.add(const Duration(days: 1)),
        to: t0.add(const Duration(days: 3)),
        label: 'pole',
      );
      expect(r.length, 1);
      expect(r.single.timestamp, t0.add(const Duration(days: 2)));
    });

    test('purga registros anteriores al corte y los dañados (CA4)', () async {
      await repo.add(rec('pole', Duration.zero));
      await repo.add(rec('pole', const Duration(days: 100)));
      await t.storage.box(EncryptedStorage.historyBox).add({'roto': true});
      final removed =
          await repo.purgeOlderThan(t0.add(const Duration(days: 10)));
      expect(removed, 2);
      expect(await repo.count(), 1);
    });

    test('clear borra el historial (CA3)', () async {
      await repo.add(rec('pole', Duration.zero));
      await repo.clear();
      expect(await repo.count(), 0);
    });
  });

  group('SettingsRepository (RF18)', () {
    test('sin datos devuelve los valores por defecto', () async {
      final repo =
          SettingsRepository(t.storage.box(EncryptedStorage.settingsBox));
      expect(await repo.load(), const AppSettings());
    });

    test('guarda y carga los ajustes', () async {
      final repo =
          SettingsRepository(t.storage.box(EncryptedStorage.settingsBox));
      const s = AppSettings(profile: UserProfile.lowVision, alertRadiusM: 30);
      await repo.save(s);
      expect(await repo.load(), s);
      await repo.clear();
      expect(await repo.load(), const AppSettings());
    });
  });

  group('AuditRepository (HU11, CA4)', () {
    test('guarda entradas y las devuelve de la más reciente a la más antigua',
        () async {
      final repo = AuditRepository(t.storage.box(EncryptedStorage.auditBox));
      await repo.add(
        ZoneAuditEntry(
            action: AuditAction.created,
            zoneId: 'a',
            zoneType: 'step',
            timestamp: t0),
      );
      await repo.add(
        ZoneAuditEntry(
          action: AuditAction.deleted,
          zoneId: 'a',
          zoneType: 'step',
          timestamp: t0.add(const Duration(minutes: 1)),
        ),
      );
      final all = await repo.all();
      expect(
          all.map((e) => e.action), [AuditAction.deleted, AuditAction.created]);
      await repo.clear();
      expect(await repo.all(), isEmpty);
    });
  });
}
