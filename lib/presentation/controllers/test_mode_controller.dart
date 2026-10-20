import 'dart:async';

import 'package:get/get.dart';

import '../../core/ai/camera_frame.dart';
import '../../core/ai/frame_gate.dart';
import '../../core/ai/i_obstacle_detector.dart';
import '../../core/config/app_constants.dart';
import '../../core/device/alert_manager.dart';
import '../../core/device/file_exporter.dart';
import '../../core/device/haptics.dart';
import '../../core/device/i_video_source.dart';
import '../../core/device/location_service.dart';
import '../../core/device/permission_guard.dart';
import '../../core/device/speech_service.dart';
import '../../core/device/video_source_selector.dart';
import '../../core/device/wakelock_service.dart';
import '../../core/metrics/metrics_csv.dart';
import '../../core/metrics/metrics_logger.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/detection.dart';
import '../../domain/entities/geo_position.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/usecases/alert_policy.dart';
import '../../domain/usecases/stability_filter.dart';

/// Casos de prueba del numeral 4.4 que se miden en el teléfono.
enum TestCase {
  cp02('CP-02', 'Latencia de inferencia (300 cuadros o más)'),
  cp03('CP-03', 'Tiempo de captura a alerta en un andén'),
  cp04('CP-04', 'Funcionamiento en modo avión'),
  cp06('CP-06', 'Reconocimiento de zonas registradas'),
  cp07('CP-07', 'Tolerancia a fallos de cámara y GPS');

  const TestCase(this.code, this.title);

  final String code;
  final String title;
}

enum TestState { idle, starting, running, failed }

/// Modo de pruebas del investigador (HU15, RF21): detección con alertas
/// reales y registro de cada cuadro en el [MetricsLogger].
///
/// Al salir de la pantalla se cierra la cámara y la aplicación vuelve a su
/// comportamiento normal (HU15, CA4).
class TestModeController extends GetxController {
  TestModeController({
    required IObstacleDetector detector,
    required VideoSourceSelector sources,
    required ISettingsRepository settings,
    required ISpeechService speech,
    required IHaptics haptics,
    required ILocationService location,
    required IPermissionGuard permissions,
    required IWakelock wakelock,
    required IFileExporter exporter,
    MetricsLogger? logger,
    DateTime Function()? clock,
  })  : _detector = detector,
        _sources = sources,
        _settings = settings,
        _speech = speech,
        _location = location,
        _permissions = permissions,
        _wakelock = wakelock,
        _exporter = exporter,
        logger = logger ?? MetricsLogger(),
        _clock = clock ?? DateTime.now,
        _alerts = AlertManager(speech: speech, haptics: haptics);

  final IObstacleDetector _detector;
  final VideoSourceSelector _sources;
  final ISettingsRepository _settings;
  final ISpeechService _speech;
  final ILocationService _location;
  final IPermissionGuard _permissions;
  final IWakelock _wakelock;
  final IFileExporter _exporter;
  final DateTime Function() _clock;
  final AlertManager _alerts;
  final MetricsLogger logger;

  /// Etiquetas reales que puede elegir el investigador (HU15, CA2).
  static const List<String> groundTruthOptions = [
    'none',
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'pole',
    'bollard',
    'traffic cone',
    'step',
    'pothole',
    'construction',
  ];

  /// Ventana de la gráfica en vivo.
  static const Duration chartWindow = Duration(seconds: 30);

  final Rx<TestState> state = TestState.idle.obs;
  final RxnString error = RxnString();
  final Rx<TestCase> testCase = TestCase.cp02.obs;
  final RxString groundTruth = 'none'.obs;
  final RxBool includeCoordinates = false.obs;

  final RxDouble fps = 0.0.obs;
  final RxDouble inferenceMs = 0.0.obs;
  final RxnDouble captureToAlertMs = RxnDouble();
  final RxInt frames = 0.obs;
  final Rx<Duration> elapsed = Duration.zero.obs;
  final RxList<Detection> detections = <Detection>[].obs;

  /// Inferencia de los últimos 30 s (gráfica).
  final RxList<double> chart = <double>[].obs;

  IVideoSource? get videoSource => _source;

  final FrameGate _gate = FrameGate();
  final StabilityFilter _stability = StabilityFilter();
  final AlertPolicy _policy = AlertPolicy();
  AppSettings _config = const AppSettings();
  IVideoSource? _source;
  // Se cancela en stop(), a través de una variable local.
  // ignore: cancel_subscriptions
  StreamSubscription<CameraFrame>? _subscription;
  Timer? _gpsTimer;
  GeoPosition? _position;
  DateTime? _startedAt;
  DateTime? _windowStart;
  int _windowCount = 0;

  bool get running => state.value == TestState.running;

  @override
  void onClose() {
    unawaited(_close());
    super.onClose();
  }

  Future<void> _close() async {
    await stop();
    await _detector.dispose();
  }

  /// Inicia la medición con el caso y la etiqueta elegidos.
  Future<void> start() async {
    if (state.value == TestState.starting || running) {
      return;
    }
    state.value = TestState.starting;
    error.value = null;
    try {
      _config = await _settings.load();
      _alerts.vibration = _config.vibration;
      await _speech.configure(rate: _config.speechRate, volume: _config.volume);
      if (!await _permissions.isGranted(AppPermission.camera) &&
          !await _permissions.request(AppPermission.camera)) {
        throw StateError('Sin permiso de cámara');
      }
      await _detector.load();
      final choice = await _sources.choose(_config.videoSource);
      final stream = await choice.source.start();
      _source = choice.source;
      _gate.reset();
      _stability.reset();
      _policy.reset();
      _alerts.reset();
      _startedAt = _clock();
      _windowStart = null;
      _windowCount = 0;
      frames.value = 0;
      chart.clear();
      _subscription = stream.listen((f) => unawaited(processFrame(f)));
      await _wakelock.enable();
      state.value = TestState.running;
      if (includeCoordinates.value) {
        _gpsTimer = Timer.periodic(
          AppConstants.positionPollInterval,
          (_) => unawaited(_updatePosition()),
        );
        unawaited(_updatePosition());
      }
    } on Object catch (e) {
      state.value = TestState.failed;
      error.value = 'No se pudo iniciar la prueba: $e';
      await _stopSource();
    }
  }

  Future<void> _updatePosition() async {
    try {
      _position = await _location.current();
    } on Object {
      _position = null;
    }
  }

  /// Detiene la medición; las muestras se conservan para exportarlas.
  Future<void> stop() async {
    final wasRunning = running || state.value == TestState.starting;
    if (wasRunning) {
      state.value = TestState.idle;
    }
    _gpsTimer?.cancel();
    _gpsTimer = null;
    await _stopSource();
    if (wasRunning) {
      await _wakelock.disable();
    }
  }

  Future<void> _stopSource() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    final source = _source;
    _source = null;
    await source?.stop();
  }

  /// Procesa un cuadro y registra su muestra (HU15, CA1 y CA2).
  Future<void> processFrame(CameraFrame frame) async {
    if (!running || !_gate.tryAcquire(frame.capturedAt)) {
      return;
    }
    try {
      final FrameDetections result;
      try {
        result = await _detector.detect(
          frame,
          confidenceThreshold: _config.confidenceThreshold,
        );
      } on Object {
        return;
      }
      if (!running) {
        return;
      }
      final now = _clock();
      _updateRate(now);
      final inference = result.inferenceMicros / 1000;
      inferenceMs.value = inference;
      frames.value++;
      final start = _startedAt;
      if (start != null) {
        elapsed.value = now.difference(start);
      }
      detections.assignAll(result.detections);
      chart.add(inference);
      final maxPoints = chartWindow.inSeconds * 12;
      if (chart.length > maxPoints) {
        chart.removeRange(0, chart.length - maxPoints);
      }

      final decision =
          _policy.decide(_stability.update(result.detections), now);
      double? toAlert;
      if (decision != null) {
        toAlert = now.difference(frame.capturedAt).inMicroseconds / 1000;
        captureToAlertMs.value = toAlert;
        _alerts.announce(decision, now);
      }
      Detection? top;
      for (final d in result.detections) {
        if (top == null || d.confidence > top.confidence) {
          top = d;
        }
      }
      final shown = decision?.detection ?? top;
      final p = includeCoordinates.value ? _position : null;
      logger.log(
        MetricSample(
          timestamp: now,
          testCase: testCase.value.code,
          fps: fps.value,
          inferenceMs: inference,
          captureToAlertMs: toAlert,
          detectedLabel: shown?.label,
          confidence: shown?.confidence,
          groundTruth: groundTruth.value,
          lat: p?.latitude,
          lng: p?.longitude,
        ),
      );
    } finally {
      _gate.release();
    }
  }

  void _updateRate(DateTime now) {
    _windowCount++;
    final start = _windowStart ??= now;
    final ms = now.difference(start).inMilliseconds;
    if (ms >= 1000) {
      fps.value = _windowCount * 1000 / ms;
      _windowCount = 0;
      _windowStart = now;
    }
  }

  MetricsSummary get summary => logger.summary();

  /// Exporta el CSV (HU15, CA3). Devuelve la ruta o `null` si no hay datos.
  Future<String?> exportCsv() async {
    if (logger.isEmpty) {
      error.value = 'Todavía no hay mediciones para exportar.';
      return null;
    }
    final stamp = _clock().toIso8601String().replaceAll(RegExp('[^0-9]'), '');
    final name =
        'eyesight_${testCase.value.code}_${stamp.substring(0, 14)}.csv';
    try {
      return await _exporter.export(
        name,
        logger.exportCsv(includeCoordinates: includeCoordinates.value),
      );
    } on Object catch (e) {
      error.value = 'No se pudo exportar: $e';
      return null;
    }
  }

  void clearSamples() {
    logger.clear();
    frames.value = 0;
    chart.clear();
    captureToAlertMs.value = null;
  }
}
