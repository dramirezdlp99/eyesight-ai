import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/presentation/controllers/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/device_fakes.dart';
import '../../support/fakes.dart';
import '../../support/scanner_fakes.dart';

void main() {
  late FakeDetector detector;
  late FakeVideoSource camera;
  late FakeSpeech speech;
  late FakeHaptics haptics;
  late FakeLocation location;
  late FakePermissions permissions;
  late FakeWakelock wakelock;
  late FakeFileExporter exporter;
  late InMemorySettingsRepository settings;
  late DateTime now;
  late TestModeController c;

  setUp(() {
    detector = FakeDetector();
    camera = FakeVideoSource();
    speech = FakeSpeech();
    haptics = FakeHaptics();
    location = FakeLocation(pos(at: t0));
    permissions = FakePermissions()..granted.addAll(AppPermission.values);
    wakelock = FakeWakelock();
    exporter = FakeFileExporter();
    settings = InMemorySettingsRepository();
    now = t0;
    c = TestModeController(
      detector: detector,
      sources: VideoSourceSelector({VideoSourceKind.phone: camera}),
      settings: settings,
      speech: speech,
      haptics: haptics,
      location: location,
      permissions: permissions,
      wakelock: wakelock,
      exporter: exporter,
      clock: () => now,
    );
  });

  tearDown(() async => c.stop());

  Future<void> frames(int n, {bool person = true}) async {
    for (var i = 0; i < n; i++) {
      now = now.add(const Duration(milliseconds: 150));
      detector.next(person ? [det('person')] : const []);
      await c.processFrame(
        frameAt(now.subtract(const Duration(milliseconds: 60))),
      );
    }
  }

  test('CA1: inicia la cámara y muestra las métricas en vivo', () async {
    await c.start();
    expect(c.running, isTrue);
    expect(camera.starts, 1);
    expect(wakelock.enabled, isTrue);
    await frames(10);
    expect(c.inferenceMs.value, 40);
    expect(c.frames.value, 10);
    expect(c.fps.value, greaterThan(0));
    expect(c.captureToAlertMs.value, 60);
    expect(speech.spoken.single, 'Persona, cerca, al frente');
  });

  test('CA2: cada cuadro queda con su caso, clase y etiqueta real', () async {
    c.testCase.value = TestCase.cp03;
    c.groundTruth.value = 'person';
    await c.start();
    await frames(4);
    expect(c.logger.length, 4);
    final last = c.logger.samples.last;
    expect(last.testCase, 'CP-03');
    expect(last.detectedLabel, 'person');
    expect(last.groundTruth, 'person');
    expect(last.inferenceMs, 40);
    expect(c.logger.samples.where((s) => s.captureToAlertMs != null),
        hasLength(1));
  });

  test('CA3: exporta el CSV sin coordenadas por defecto', () async {
    await c.start();
    await frames(3);
    await c.stop();
    final path = await c.exportCsv();
    expect(path, isNotNull);
    final csv = exporter.files.values.single;
    expect(exporter.files.keys.single, startsWith('eyesight_CP-02_'));
    expect(csv, isNot(contains('latitud')));
    expect(csv.trim().split('\r\n'), hasLength(4));
  });

  test('CA3: sin mediciones no exporta y lo informa', () async {
    expect(await c.exportCsv(), isNull);
    expect(c.error.value, isNotNull);
    expect(exporter.files, isEmpty);
  });

  test('CA4: al detener se apaga la cámara y la pantalla vuelve a lo normal',
      () async {
    await c.start();
    await c.stop();
    expect(c.running, isFalse);
    expect(camera.stops, 1);
    expect(wakelock.enabled, isFalse);
    await frames(2);
    expect(c.logger.length, 0);
  });

  test('sin permiso de cámara informa el error', () async {
    permissions
      ..granted.clear()
      ..grantOnRequest = false;
    await c.start();
    expect(c.state.value, TestState.failed);
    expect(c.error.value, contains('cámara'));
  });

  test('los hilos elegidos se guardan, los usa el modelo y van al CSV',
      () async {
    await c.loadThreads();
    expect(c.threads.value, 4);
    await c.setThreads(2);
    expect(settings.value.inferenceThreads, 2);
    await c.setThreads(3); // no es una opción válida
    expect(c.threads.value, 2);
    await c.start();
    expect(detector.threads, 2);
    await frames(1);
    expect(c.logger.samples.single.threads, 2);
    await c.setThreads(6); // no cambia mientras mide
    expect(c.threads.value, 2);
  });

  test('borrar mediciones', () async {
    await c.start();
    await frames(2, person: false);
    await c.stop();
    c.clearSamples();
    expect(c.logger.isEmpty, isTrue);
    expect(c.frames.value, 0);
  });
}
