import 'dart:ui';

import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/detection.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';
import 'package:eyesight_ai/domain/usecases/alert_policy.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:eyesight_ai/presentation/controllers/scanner_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/device_fakes.dart';
import '../../support/fakes.dart';
import '../../support/scanner_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDetector detector;
  late FakeVideoSource phone;
  late FakeVideoSource usb;
  late FakeSpeech speech;
  late FakeVoice voice;
  late FakeHaptics haptics;
  late FakeLocation location;
  late FakePermissions permissions;
  late FakeWakelock wakelock;
  late InMemorySettingsRepository settings;
  late InMemoryZoneRepository zones;
  late InMemoryHistoryRepository history;
  late FakePeriodic periodic;
  late DateTime now;
  late ScannerController c;

  /// Obstáculo lejos y fuera de la trayectoria: no se anuncia.
  const sideFar = Rect.fromLTRB(0.0, 0.1, 0.1, 0.3);

  /// Obstáculo a media distancia en la trayectoria.
  const pathMedium = Rect.fromLTRB(0.4, 0.4, 0.6, 0.7);

  setUp(() {
    detector = FakeDetector();
    phone = FakeVideoSource();
    usb = FakeVideoSource(kind: VideoSourceKind.usb, available: false);
    speech = FakeSpeech();
    voice = FakeVoice(const [], true);
    haptics = FakeHaptics();
    location = FakeLocation();
    permissions = FakePermissions()..granted.addAll(AppPermission.values);
    wakelock = FakeWakelock();
    settings = InMemorySettingsRepository();
    zones = InMemoryZoneRepository();
    history = InMemoryHistoryRepository();
    periodic = FakePeriodic();
    now = t0;
  });

  ScannerController build({bool listen = false}) => ScannerController(
        detector: detector,
        sources: VideoSourceSelector({
          VideoSourceKind.phone: phone,
          VideoSourceKind.usb: usb,
        }),
        speech: speech,
        voice: voice,
        haptics: haptics,
        location: location,
        permissions: permissions,
        wakelock: wakelock,
        settings: settings,
        zones: zones,
        history: history,
        zoneService: ZoneService(
          zones: zones,
          audit: InMemoryAuditRepository(),
          clock: () => now,
          newId: sequentialIds('zona'),
        ),
        clock: () => now,
        periodic: periodic.call,
        autoStart: false,
        listenForCommands: listen,
      );

  Future<ScannerController> started({bool listen = false}) async {
    c = build(listen: listen);
    await c.startScan();
    speech.spoken.clear();
    haptics.played.clear();
    return c;
  }

  /// Un cuadro 150 ms después del anterior, capturado 50 ms antes de
  /// procesarse.
  Future<void> frame(List<Detection> detections) async {
    now = now.add(const Duration(milliseconds: 150));
    detector.next(detections);
    await c.processFrame(
      frameAt(now.subtract(const Duration(milliseconds: 50))),
    );
  }

  Future<void> frames(int n, List<Detection> detections) async {
    for (var i = 0; i < n; i++) {
      await frame(detections);
    }
  }

  tearDown(() async {
    await c.stopScan();
  });

  group('HU02: inicio automático del escáner', () {
    test('inicia, anuncia «Escáner activo» y mantiene la pantalla encendida',
        () async {
      c = build();
      await c.startScan();
      expect(c.state.value, ScanState.scanning);
      expect(speech.spoken.first, ScannerController.startedMessage);
      expect(wakelock.enabled, isTrue);
      expect(phone.starts, 1);
      expect(detector.isReady, isTrue);
      expect(periodic.active, isTrue);
      expect(
        c.startupMs.value,
        lessThan(const Duration(seconds: 3).inMilliseconds),
      );
    });

    test('CA2: explica para qué es el permiso antes de pedirlo', () async {
      permissions.granted.clear();
      c = build();
      await c.startScan();
      expect(
        speech.spoken.first,
        ScannerController.permissionReason(AppPermission.camera),
      );
      expect(permissions.requested.first, AppPermission.camera);
      expect(c.state.value, ScanState.scanning);
    });

    test('sin permiso de cámara no inicia y lo explica', () async {
      permissions
        ..granted.clear()
        ..grantOnRequest = false;
      c = build();
      await c.startScan();
      expect(c.state.value, ScanState.failed);
      expect(speech.spoken.last, ScannerController.cameraDeniedMessage);
      expect(phone.starts, 0);
    });

    test('CA5: sin cámara USB usa la del teléfono y lo anuncia', () async {
      settings.value = const AppSettings(videoSource: VideoSourceKind.usb);
      c = build();
      await c.startScan();
      expect(phone.starts, 1);
      expect(speech.spoken, contains(ScannerController.usbFallbackMessage));
    });

    test('RNF16: si el modelo no carga lo anuncia', () async {
      detector.failOnLoad = true;
      c = build();
      await c.startScan();
      expect(c.state.value, ScanState.failed);
      expect(speech.spoken.last, ScannerController.detectionFailedMessage);
    });

    test('al detener libera cámara, GPS y pantalla', () async {
      await started();
      await c.stopScan(announce: true);
      expect(c.state.value, ScanState.stopped);
      expect(phone.stops, 1);
      expect(wakelock.enabled, isFalse);
      expect(periodic.active, isFalse);
      expect(speech.spoken.last, ScannerController.stoppedMessage);
    });

    test('al pasar a segundo plano se detiene y al volver se reanuda',
        () async {
      await started();
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.value, ScanState.stopped);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.value, ScanState.scanning);
      expect(phone.starts, 2);
    });
  });

  group('HU03: alerta de voz', () {
    test('CA1: confirma en 3 cuadros y anuncia tipo, cercanía y dirección',
        () async {
      await started();
      await frames(2, [det('person')]);
      expect(speech.spoken, isEmpty);
      await frame([det('person')]);
      expect(speech.spoken, ['Persona, cerca, al frente']);
      expect(c.headline.value, 'Persona, cerca, al frente');
      expect(c.headlineProximity.value, Proximity.near);
    });

    test('CA2: no repite el mismo obstáculo antes de 4 s', () async {
      await started();
      await frames(10, [det('person')]);
      expect(speech.spoken, hasLength(1));
      now = now.add(const Duration(seconds: 4));
      await frame([det('person')]);
      expect(speech.spoken, hasLength(2));
    });

    test('CA4: lo que está lejos y fuera de la trayectoria no se anuncia',
        () async {
      await started();
      await frames(4, [
        det('person', box: sideFar, proximity: Proximity.far, inPath: false),
      ]);
      expect(speech.spoken, isEmpty);
    });

    test('CA5: mide el tiempo de captura a alerta', () async {
      await started();
      await frames(3, [det('person')]);
      expect(c.captureToAlertMs.value, 50);
      expect(
        c.captureToAlertMs.value,
        lessThanOrEqualTo(500),
      );
      expect(c.inferenceMs.value, 40);
    });

    test('usa el umbral de confianza de los ajustes (HU13)', () async {
      settings.value = const AppSettings(confidenceThreshold: 0.7);
      await started();
      await frame([]);
      expect(detector.lastThreshold, 0.7);
    });

    test('cada alerta queda en el historial (RF17)', () async {
      await started();
      await frames(3, [det('person')]);
      expect(history.records, hasLength(1));
      expect(history.records.single.label, 'person');
      expect(history.records.single.hasPosition, isFalse);
    });

    test('RNF16: tres fallos seguidos del modelo se anuncian una vez',
        () async {
      await started();
      detector.failOnDetect = true;
      await frames(5, []);
      expect(
        speech.spoken
            .where((s) => s == ScannerController.detectionFailedMessage),
        hasLength(1),
      );
    });
  });

  group('HU04: vibración según la cercanía', () {
    test('cerca: 3 pulsos; media distancia: 2 pulsos', () async {
      await started();
      await frames(3, [det('person')]);
      expect(haptics.played.last, HapticPatterns.near);
      await frames(3, [
        det('car', box: pathMedium, proximity: Proximity.medium),
      ]);
      expect(haptics.played.last, HapticPatterns.medium);
    });

    test('CA4: con la vibración desactivada solo habla', () async {
      settings.value = const AppSettings(vibration: false);
      await started();
      await frames(3, [det('person')]);
      expect(haptics.played, isEmpty);
      expect(speech.spoken, hasLength(1));
    });
  });

  group('HU06: zonas automáticas', () {
    test('un poste cercano con GPS crea una zona automática', () async {
      location.position = pos(at: t0);
      await started();
      await c.pollZones();
      await frames(3, [det('pole')]);
      expect(zones.zones.values, hasLength(1));
      final z = zones.zones.values.single;
      expect(z.type, 'pole');
      expect(z.origin, ZoneOrigin.automatic);
      expect(history.records.single.hasPosition, isTrue);
    });

    test('CA3: una persona no crea zona', () async {
      location.position = pos(at: t0);
      await started();
      await c.pollZones();
      await frames(3, [det('person')]);
      expect(zones.zones, isEmpty);
    });

    test('CA4: sin GPS solo se guarda en el historial', () async {
      await started();
      await frames(3, [det('pothole')]);
      expect(zones.zones, isEmpty);
      expect(history.records, hasLength(1));
    });
  });

  group('HU07: marcar zona por voz o gesto', () {
    setUp(() => location.position = pos(at: t0));

    test('CA1 y CA2: pregunta el tipo y guarda la zona manual', () async {
      await started(listen: true);
      await c.markZone();
      expect(c.dialog.value, ScannerDialog.zoneType);
      expect(speech.spoken, contains(ScannerController.askZoneTypeMessage));

      await c.handleVoice('un hueco');
      expect(c.dialog.value, ScannerDialog.none);
      final z = zones.zones.values.single;
      expect(z.type, 'pothole');
      expect(z.origin, ZoneOrigin.manual);
      expect(speech.spoken.last, 'Zona de hueco guardada.');
      expect(haptics.played.last, HapticPatterns.zone);
    });

    test('CA3: «cancelar» no guarda la zona', () async {
      await started(listen: true);
      await c.markZone();
      await c.handleVoice('cancelar');
      expect(zones.zones, isEmpty);
      expect(speech.spoken.last, ScannerController.zoneCanceledMessage);
    });

    test('CA3: sin respuesta en 8 s no guarda la zona', () async {
      await started(listen: true);
      await c.markZone();
      await c.handleVoice(null);
      expect(c.dialog.value, ScannerDialog.zoneType);
      now = now.add(const Duration(seconds: 9));
      await c.handleVoice(null);
      expect(c.dialog.value, ScannerDialog.none);
      expect(zones.zones, isEmpty);
    });

    test('CA4: sin GPS informa que no fue posible', () async {
      location.position = null;
      await started(listen: true);
      await c.markZone();
      await c.handleVoice('escalón');
      expect(zones.zones, isEmpty);
      expect(speech.spoken.last, ScannerController.zoneNoGpsMessage);
    });

    test('sin reconocimiento de voz la marca como riesgo genérico', () async {
      voice.available = false;
      await started(listen: true);
      expect(c.voiceReady, isFalse);
      await c.markZone();
      expect(zones.zones.values.single.type, 'other');
      expect(speech.spoken.last, 'Zona de riesgo guardada.');
    });
  });

  group('HU08: alerta preventiva de zona', () {
    setUp(() {
      zones.zones['z1'] = zone(lat: pastoLat + metersToLat(15));
    });

    test('CA1: anuncia la zona y vibra con un pulso largo', () async {
      location.position = pos(at: t0);
      await started();
      await c.pollZones();
      expect(speech.spoken.last, 'Atención: hueco a 15 metros');
      expect(haptics.played.last, HapticPatterns.zone);
      expect(c.headline.value, 'Atención: hueco a 15 metros');
    });

    test('CA2: no repite la zona mientras sigue cerca', () async {
      location.position = pos(at: t0);
      await started();
      await c.pollZones();
      now = now.add(const Duration(seconds: 3));
      await c.pollZones();
      expect(
        speech.spoken.where((s) => s.startsWith('Atención')),
        hasLength(1),
      );
    });

    test('CA4: con precisión peor que 30 m no avisa, pero informa una vez',
        () async {
      location.position = pos(at: t0, accuracy: 45);
      await started();
      await c.pollZones();
      await c.pollZones();
      expect(speech.spoken, [ScannerController.noGpsMessage]);
    });

    test('el temporizador consulta la posición cada 3 s', () async {
      location.position = pos(at: t0);
      await started();
      periodic.callbacks.single(periodic.timers.single);
      await Future<void>.delayed(Duration.zero);
      expect(speech.spoken.last, 'Atención: hueco a 15 metros');
    });
  });

  group('HU09: comandos de voz y gestos', () {
    test('CA1: «repetir» repite la última alerta', () async {
      await started();
      await frames(3, [det('person')]);
      await c.handleVoice('repite por favor');
      expect(speech.spoken, [
        'Persona, cerca, al frente',
        'Persona, cerca, al frente',
      ]);
    });

    test('sin alertas, «repetir» lo informa', () async {
      await started();
      c.repeatLast();
      expect(speech.spoken.single, ScannerController.noAlertMessage);
    });

    test('CA2: «silencio» pausa la voz 10 s; lo cercano sigue vibrando',
        () async {
      await started();
      await c.handleVoice('silencio');
      expect(c.muted.value, isTrue);
      speech.spoken.clear();

      await frames(3, [
        det('car', box: pathMedium, proximity: Proximity.medium),
      ]);
      expect(speech.spoken, isEmpty);
      expect(haptics.played, isEmpty);

      await frames(3, [det('person')]);
      expect(speech.spoken, isEmpty);
      expect(haptics.played.single, HapticPatterns.near);

      now = now.add(const Duration(seconds: 10));
      await frames(3, [det('dog')]);
      expect(speech.spoken, ['Perro, cerca, al frente']);
      expect(c.muted.value, isFalse);
    });

    test('CA3: «terminar» pide confirmación y «sí» detiene', () async {
      await started(listen: true);
      await c.handleVoice('terminar');
      expect(c.dialog.value, ScannerDialog.confirmStop);
      expect(speech.spoken.last, ScannerController.askStopMessage);
      await c.handleVoice('sí');
      expect(c.state.value, ScanState.stopped);
      expect(speech.spoken.last, ScannerController.stoppedMessage);
    });

    test('CA3: con «no» el escáner sigue activo', () async {
      await started(listen: true);
      await c.handleVoice('terminar');
      await c.handleVoice('no');
      expect(c.state.value, ScanState.scanning);
      expect(speech.spoken.last, ScannerController.continueMessage);
    });

    test('CA4: un comando no reconocido no hace nada', () async {
      await started(listen: true);
      await c.handleVoice('qué hora es');
      expect(speech.spoken, isEmpty);
      expect(c.dialog.value, ScannerDialog.none);
      expect(c.state.value, ScanState.scanning);
    });

    test('la escucha continua se detiene con el escáner', () async {
      await started(listen: true);
      await Future<void>.delayed(Duration.zero);
      expect(voice.listens, greaterThan(0));
      await c.stopScan();
      expect(voice.stops, greaterThan(0));
    });
  });
}
