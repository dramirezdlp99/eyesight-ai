import 'package:eyesight_ai/core/device/earcons.dart';
import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:eyesight_ai/core/security/zone_backup.dart';
import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/detection_record.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/domain/entities/zone_audit_entry.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';
import 'package:eyesight_ai/domain/usecases/alert_policy.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:eyesight_ai/presentation/controllers/history_controller.dart';
import 'package:eyesight_ai/presentation/controllers/privacy_controller.dart';
import 'package:eyesight_ai/presentation/controllers/settings_controller.dart';
import 'package:eyesight_ai/presentation/controllers/zones_controller.dart';
import 'package:eyesight_ai/presentation/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/device_fakes.dart';
import '../../support/fakes.dart';
import '../../support/scanner_fakes.dart';

DetectionRecord record(String label, DateTime at,
        {Proximity proximity = Proximity.near}) =>
    DetectionRecord(
      label: label,
      confidence: 0.8,
      proximity: proximity,
      timestamp: at,
    );

void main() {
  group('ZonesController (HU10, HU11)', () {
    late InMemoryZoneRepository zones;
    late InMemoryAuditRepository audit;
    late FakeLocation location;
    late FakePermissions permissions;
    late ZonesController c;

    setUp(() async {
      zones = InMemoryZoneRepository();
      audit = InMemoryAuditRepository();
      location = FakeLocation(pos(lat: pastoLat - metersToLat(40)));
      permissions = FakePermissions();
      zones.zones['a'] = zone(
        id: 'a',
        lastSeen: t0.subtract(const Duration(days: 2)),
      );
      zones.zones['m'] = zone(
        id: 'm',
        type: 'step',
        origin: ZoneOrigin.manual,
        lastSeen: t0.subtract(const Duration(days: 1)),
      );
      c = ZonesController(
        zones: zones,
        service: ZoneService(zones: zones, audit: audit, clock: () => t0),
        location: location,
        permissions: permissions,
        clock: () => t0,
      );
      await c.load();
    });

    test('CA1: lista las zonas, la más reciente primero, con su origen', () {
      expect(c.visible.map((z) => z.id), ['m', 'a']);
      expect(c.automaticCount, 1);
      expect(c.manualCount, 1);
    });

    test('CA3: el filtro de origen deja solo esas zonas', () {
      c.setFilter(ZoneFilter.automatic);
      expect(c.visible.single.id, 'a');
      c.setFilter(ZoneFilter.manual);
      expect(c.visible.single.id, 'm');
    });

    test('sin permiso de ubicación no la pide ni mide distancias', () {
      expect(permissions.requested, isEmpty);
      expect(c.position.value, isNull);
      expect(c.distanceTo(c.visible.first), isNull);
    });

    test('con permiso calcula la distancia a cada zona', () async {
      permissions.granted.add(AppPermission.location);
      await c.load();
      expect(c.distanceTo(c.byId('a')!), closeTo(40, 0.5));
    });

    test('fechas relativas: hoy, ayer y hace N días', () {
      expect(c.ago(t0), 'hoy');
      expect(c.ago(t0.subtract(const Duration(days: 1))), 'ayer');
      expect(c.ago(t0.subtract(const Duration(days: 5))), 'hace 5 días');
    });

    test('CA1 y CA4 (HU11): edita tipo, radio y nota y queda registrado',
        () async {
      final error = await c.save(
        'a',
        type: 'pole',
        radiusM: 35,
        note: 'Frente a la tienda',
      );
      expect(error, isNull);
      final z = c.byId('a')!;
      expect(z.type, 'pole');
      expect(z.radiusM, 35);
      expect(z.note, 'Frente a la tienda');
      expect(audit.entries.last.action, AuditAction.edited);
    });

    test('CA2 (HU11): rechaza radios fuera de 5 a 100 m y notas largas',
        () async {
      expect(
        await c.save('a', type: 'pole', radiusM: 120, note: ''),
        contains('radio'),
      );
      expect(
        await c.save('a', type: 'pole', radiusM: 20, note: 'x' * 101),
        contains('100'),
      );
      expect(c.byId('a')!.type, 'pothole');
    });

    test('CA3 (HU11): eliminar borra la zona', () async {
      expect(await c.delete('m'), isTrue);
      expect(c.byId('m'), isNull);
      expect(zones.zones.containsKey('m'), isFalse);
      expect(audit.entries.last.action, AuditAction.deleted);
    });
  });

  group('HistoryController (HU12)', () {
    late InMemoryHistoryRepository history;
    late HistoryController c;

    setUp(() async {
      history = InMemoryHistoryRepository();
      history.records.addAll([
        record('pole', t0.subtract(const Duration(hours: 1))),
        record('person', t0.subtract(const Duration(hours: 2))),
        record('pole', t0.subtract(const Duration(days: 3))),
        record('car', t0.subtract(const Duration(days: 20))),
      ]);
      c = HistoryController(history: history, clock: () => t0);
      await c.load();
    });

    test('CA1: de la más reciente a la más antigua (7 días por defecto)', () {
      expect(c.records.map((r) => r.label), ['pole', 'person', 'pole']);
    });

    test('CA2: filtra por fecha y tipo a la vez', () async {
      await c.setRange(HistoryRange.today);
      expect(c.records, hasLength(2));
      await c.setLabel('pole');
      expect(c.records, hasLength(1));
      await c.setRange(HistoryRange.month);
      expect(c.records, hasLength(2));
      await c.setRange(HistoryRange.all);
      await c.setLabel(null);
      expect(c.records, hasLength(4));
    });

    test('gráfica de la semana y tipos disponibles', () {
      expect(c.lastWeek, [0, 0, 0, 1, 0, 0, 2]);
      expect(c.labels, ['car', 'person', 'pole']);
    });

    test('CA3: borrar el historial elimina todo', () async {
      await c.clearAll();
      expect(history.records, isEmpty);
      expect(c.records, isEmpty);
    });
  });

  group('SettingsController (HU13)', () {
    late InMemorySettingsRepository settings;
    late FakeSpeech speech;
    late FakeVideoSource usb;
    late FakeHaptics haptics;
    late FakeEarcons earcons;
    late SettingsController c;

    setUp(() async {
      settings = InMemorySettingsRepository(
        const AppSettings(profile: UserProfile.companion),
      );
      speech = FakeSpeech();
      usb = FakeVideoSource(kind: VideoSourceKind.usb, available: false);
      haptics = FakeHaptics();
      earcons = FakeEarcons();
      c = SettingsController(
        settings: settings,
        speech: speech,
        sources: VideoSourceSelector({
          VideoSourceKind.phone: FakeVideoSource(),
          VideoSourceKind.usb: usb,
        }),
        haptics: haptics,
        earcons: earcons,
      );
      await c.load();
    });

    test('pitidos: se guardan y se pueden probar', () async {
      await c.setBeeps(false);
      expect(settings.value.beeps, isFalse);
      await c.testBeeps();
      expect(earcons.played, [
        Earcons.near,
        Earcons.medium,
        Earcons.far,
        Earcons.zone,
      ]);
    });

    test('probar vibración reproduce el patrón de «cerca»', () async {
      await c.testVibration();
      expect(haptics.played.single, HapticPatterns.near);
    });

    test('CA1: al cambiar la voz se guarda y suena una frase de ejemplo',
        () async {
      await c.setVoice(rate: 1.4);
      expect(settings.value.speechRate, 1.4);
      expect(speech.rate, 1.4);
      expect(speech.spoken.single, SettingsController.sample);
      await c.setVoice(volume: 0.6);
      expect(settings.value.volume, 0.6);
    });

    test('CA2: solo acepta radios de 5 a 100 m y umbrales de 0,30 a 0,90',
        () async {
      expect(await c.setRadius(3), isFalse);
      expect(c.message.value, isNotNull);
      expect(await c.setRadius(40), isTrue);
      expect(settings.value.alertRadiusM, 40);
      expect(await c.setConfidence(0.95), isFalse);
      expect(await c.setConfidence(0.65), isTrue);
      expect(settings.value.confidenceThreshold, 0.65);
    });

    test('CA3: sin cámara USB lo informa y mantiene la del teléfono', () async {
      await c.setVideoSource(VideoSourceKind.usb);
      expect(c.message.value, SettingsController.usbMissing);
      expect(settings.value.videoSource, VideoSourceKind.phone);
      usb.available = true;
      await c.setVideoSource(VideoSourceKind.usb);
      expect(settings.value.videoSource, VideoSourceKind.usb);
    });

    test('vibración y zonas automáticas', () async {
      await c.setVibration(false);
      await c.setAutoZones(false);
      expect(settings.value.vibration, isFalse);
      expect(settings.value.autoZones, isFalse);
    });

    test('CA4: restablecer recupera los valores y conserva el perfil',
        () async {
      await c.setRadius(80);
      await c.reset();
      expect(settings.value, const AppSettings(profile: UserProfile.companion));
      expect(c.message.value, SettingsController.resetDone);
    });

    test('formato de las etiquetas', () {
      expect(SettingsController.rateLabel(1), '1,0×');
      expect(SettingsController.percent(0.6), '60 %');
      expect(SettingsController.confidenceLabel(0.5), '0,50');
    });
  });

  group('PrivacyController (HU14)', () {
    late InMemoryZoneRepository zones;
    late InMemoryHistoryRepository history;
    late InMemoryAuditRepository audit;
    late FakePermissions permissions;
    late PinGuard pin;
    late List<String> routes;
    late int wipes;
    late FakeFileExporter exporter;
    late PrivacyController c;

    ZoneBackup fastBackup() => ZoneBackup(
          iterations: 1000,
          derive: (p, s, it) async => PinHasher.pbkdf2(p, s, it, 64),
        );

    setUp(() async {
      zones = InMemoryZoneRepository()..zones['a'] = zone(id: 'a');
      history = InMemoryHistoryRepository()..records.add(record('pole', t0));
      audit = InMemoryAuditRepository();
      permissions = FakePermissions()..granted.add(AppPermission.camera);
      final hasher = PinHasher(iterations: 200);
      pin = PinGuard(
        InMemorySecureStore(),
        hash: (p) async => hasher.hash(p),
        verify: (p, h) async => PinHasher.verify(p, h),
        clock: () => t0,
      );
      await pin.setPin('1357');
      routes = [];
      wipes = 0;
      exporter = FakeFileExporter();
      c = PrivacyController(
        zones: zones,
        history: history,
        audit: audit,
        permissions: permissions,
        pin: pin,
        wipe: () async => wipes++,
        navigate: routes.add,
        zoneService: ZoneService(zones: zones, audit: audit, clock: () => t0),
        exporter: exporter,
        backup: fastBackup(),
      );
      await c.load();
    });

    test('CA1: muestra cantidades y el estado de cada permiso', () {
      expect(c.zoneCount.value, 1);
      expect(c.historyCount.value, 1);
      expect(c.auditCount.value, 0);
      expect(c.permissions[AppPermission.camera], isTrue);
      expect(c.permissions[AppPermission.location], isFalse);
      expect(permissions.requested, isEmpty);
    });

    test('exportar e importar zonas cifradas en otro teléfono', () async {
      zones.zones['b'] = zone(id: 'b', type: 'step', note: 'Frente al parque');
      expect(await c.exportZones('secreta1', 'secreta1'), isNull);
      final text = exporter.shared.single;
      expect(text, startsWith(ZoneBackup.header));
      expect(text, isNot(contains('Frente al parque'))); // va cifrado

      // Otro teléfono, sin zonas.
      final otherZones = InMemoryZoneRepository();
      final otherAudit = InMemoryAuditRepository();
      final other = PrivacyController(
        zones: otherZones,
        history: InMemoryHistoryRepository(),
        audit: otherAudit,
        permissions: permissions,
        pin: pin,
        wipe: () async {},
        navigate: (_) {},
        zoneService: ZoneService(zones: otherZones, audit: otherAudit),
        exporter: FakeFileExporter(),
        backup: fastBackup(),
      );
      final (ok, message) = await other.importZones(text, 'secreta1');
      expect(ok, isTrue);
      expect(message, contains('2 zonas'));
      expect(otherZones.zones['b']!.note, 'Frente al parque');
      expect(otherAudit.entries, hasLength(2));

      // Importar de nuevo no duplica.
      final (_, again) = await other.importZones(text, 'secreta1');
      expect(again, contains('0 zonas'));
      expect(otherZones.zones, hasLength(2));
    });

    test('la importación rechaza contraseña incorrecta y texto incompleto',
        () async {
      await c.exportZones('secreta1', 'secreta1');
      final text = exporter.shared.single;
      final (ok1, wrong) = await c.importZones(text, 'otraclave');
      expect(ok1, isFalse);
      expect(wrong, contains('incorrecta'));
      final (ok2, partial) =
          await c.importZones(text.substring(0, text.length ~/ 2), 'secreta1');
      expect(ok2, isFalse);
      expect(partial, isNotEmpty);
      final (ok3, foreign) = await c.importZones('hola', 'secreta1');
      expect(ok3, isFalse);
      expect(foreign, contains('no es una copia'));
    });

    test('exportar valida la contraseña y que haya zonas', () async {
      expect(await c.exportZones('123', '123'), contains('6 caracteres'));
      expect(
          await c.exportZones('secreta1', 'secreta2'), contains('coinciden'));
      zones.zones.clear();
      expect(await c.exportZones('secreta1', 'secreta1'), contains('no hay'));
      expect(exporter.shared, isEmpty);
    });

    test('CA2: sin escribir ELIMINAR no borra nada', () async {
      expect(await c.wipeAll('eliminar'), isFalse);
      expect(await c.wipeAll(''), isFalse);
      expect(wipes, 0);
      expect(routes, isEmpty);
    });

    test('CA2: con ELIMINAR borra todo y vuelve a elegir perfil', () async {
      expect(await c.wipeAll(' ELIMINAR '), isTrue);
      expect(wipes, 1);
      expect(routes, [AppRoutes.profile]);
    });

    test('CA3: cambia el PIN con el actual correcto', () async {
      expect(await c.changePin('1357', '2468', '2468'), isNull);
      expect(await pin.verify('2468'), isA<PinAccepted>());
    });

    test('CA3: rechaza PIN actual incorrecto, inválido o sin coincidir',
        () async {
      expect(await c.changePin('0000', '2468', '2468'), contains('incorrecto'));
      expect(await c.changePin('1357', '12', '12'), isNotNull);
      expect(await c.changePin('1357', '2468', '2469'), contains('coinciden'));
      expect(await pin.verify('1357'), isA<PinAccepted>());
    });
  });
}
