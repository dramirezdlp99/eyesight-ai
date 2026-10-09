import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/ai/camera_frame.dart';
import '../../core/ai/frame_gate.dart';
import '../../core/ai/i_obstacle_detector.dart';
import '../../core/ai/obstacle_catalog.dart';
import '../../core/config/app_constants.dart';
import '../../core/device/haptics.dart';
import '../../core/device/i_video_source.dart';
import '../../core/device/location_service.dart';
import '../../core/device/permission_guard.dart';
import '../../core/device/speech_service.dart';
import '../../core/device/video_source_selector.dart';
import '../../core/device/voice_input.dart';
import '../../core/device/wakelock_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/detection.dart';
import '../../domain/entities/detection_record.dart';
import '../../domain/entities/geo_position.dart';
import '../../domain/entities/proximity.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../../domain/usecases/alert_policy.dart';
import '../../domain/usecases/stability_filter.dart';
import '../../domain/usecases/voice_command_parser.dart';
import '../../domain/usecases/zone_monitor.dart';
import '../../domain/usecases/zone_registration_policy.dart';
import '../../domain/usecases/zone_service.dart';

/// Estado del escáner.
enum ScanState { idle, starting, scanning, stopped, failed }

/// Pregunta por voz en curso.
enum ScannerDialog {
  none,

  /// «¿Qué tipo de riesgo?» al marcar una zona (HU07).
  zoneType,

  /// «¿Deseas terminar el escáner?» (HU09, CA3).
  confirmStop,
}

/// Crea un temporizador periódico. Se inyecta para probar el monitoreo de
/// zonas sin esperar tiempo real.
typedef PeriodicTimerFactory = Timer Function(
  Duration period,
  void Function(Timer timer) callback,
);

/// Orquesta el escáner del usuario final (HU02 a HU09, diagrama de clases).
///
/// Une la fuente de video, el detector, el filtro de estabilidad, la
/// política de alertas, la voz, la vibración, los comandos de voz, los
/// gestos y la memoria georreferenciada de zonas de riesgo.
class ScannerController extends GetxController with WidgetsBindingObserver {
  ScannerController({
    required IObstacleDetector detector,
    required VideoSourceSelector sources,
    required ISpeechService speech,
    required IVoiceInput voice,
    required IHaptics haptics,
    required ILocationService location,
    required IPermissionGuard permissions,
    required IWakelock wakelock,
    required ISettingsRepository settings,
    required IZoneRepository zones,
    required IHistoryRepository history,
    required ZoneService zoneService,
    DateTime Function()? clock,
    PeriodicTimerFactory? periodic,
    this.autoStart = true,
    this.listenForCommands = true,
  })  : _detector = detector,
        _sources = sources,
        _speech = speech,
        _voice = voice,
        _haptics = haptics,
        _location = location,
        _permissions = permissions,
        _wakelock = wakelock,
        _settings = settings,
        _zones = zones,
        _history = history,
        _zoneService = zoneService,
        _clock = clock ?? DateTime.now,
        _periodic = periodic ?? Timer.periodic;

  final IObstacleDetector _detector;
  final VideoSourceSelector _sources;
  final ISpeechService _speech;
  final IVoiceInput _voice;
  final IHaptics _haptics;
  final ILocationService _location;
  final IPermissionGuard _permissions;
  final IWakelock _wakelock;
  final ISettingsRepository _settings;
  final IZoneRepository _zones;
  final IHistoryRepository _history;
  final ZoneService _zoneService;
  final DateTime Function() _clock;
  final PeriodicTimerFactory _periodic;

  /// Inicia el escáner al abrir la pantalla (HU02, CA1).
  final bool autoStart;

  /// Escucha comandos de voz de forma continua (HU09). Las pruebas lo
  /// desactivan y llaman a [handleVoice] directamente.
  final bool listenForCommands;

  // ------------------------------------------------------------- Mensajes
  static const String startedMessage =
      'Escáner activo. EyeSight AI complementa tu bastón, no lo reemplaza.';
  static const String usbFallbackMessage =
      'La cámara USB no está conectada. Uso la cámara del teléfono.';
  static const String cameraDeniedMessage =
      'Sin permiso de cámara no puedo detectar obstáculos. '
      'Actívalo en los ajustes del teléfono.';
  static const String cameraFailedMessage =
      'No pude abrir la cámara. Usa tu bastón con precaución.';
  static const String detectionFailedMessage =
      'Falla en la detección de obstáculos. Usa tu bastón con precaución.';
  static const String noGpsMessage =
      'Sin señal GPS precisa. Las zonas de riesgo no están disponibles por ahora.';
  static const String noVoiceMessage =
      'Los comandos de voz no están disponibles. Usa los gestos.';
  static const String mutedMessage = 'Silencio por 10 segundos.';
  static const String noAlertMessage = 'Todavía no hay alertas.';
  static const String askZoneTypeMessage =
      '¿Qué tipo de riesgo? Di: hueco, escalón, obra u otro.';
  static const String zoneCanceledMessage = 'No se guardó la zona.';
  static const String zoneNoGpsMessage =
      'No fue posible registrar la zona: no hay señal GPS precisa.';
  static const String askStopMessage =
      '¿Deseas terminar el escáner? Di sí o no.';
  static const String continueMessage = 'El escáner sigue activo.';
  static const String stoppedMessage = 'Escáner detenido.';

  static String permissionReason(AppPermission p) =>
      'EyeSight AI necesita ${p.reason}.';

  static String zoneSavedMessage(String type) =>
      'Zona de ${ObstacleCatalog.spanishName(type).toLowerCase()} guardada.';

  // ------------------------------------------------------- Estado visible
  final Rx<ScanState> state = ScanState.idle.obs;
  final RxString status = 'Preparando el escáner…'.obs;

  /// Último aviso (obstáculo o zona) en texto, para la vista de alto
  /// contraste (HU05) y el comando «repetir» (HU09).
  final RxString headline = ''.obs;

  /// Cercanía del último obstáculo anunciado; `null` para avisos de zona.
  final Rxn<Proximity> headlineProximity = Rxn<Proximity>();
  final RxBool muted = false.obs;
  final Rx<ScannerDialog> dialog = ScannerDialog.none.obs;

  /// Métricas en vivo (RNF01 a RNF03, HU02 CA1 y HU03 CA5).
  final RxDouble fps = 0.0.obs;
  final RxInt inferenceMs = 0.obs;
  final RxInt captureToAlertMs = 0.obs;
  final RxInt startupMs = 0.obs;

  /// `true` si el reconocimiento de voz está disponible.
  bool get voiceReady => _voiceReady;

  // ------------------------------------------------------- Estado interno
  final FrameGate _gate = FrameGate();
  final StabilityFilter _stability = StabilityFilter();
  final AlertPolicy _alerts = AlertPolicy();
  final ZoneMonitor _monitor = ZoneMonitor();
  final Map<String, DateTime> _lastZoneAttempt = {};

  AppSettings _config = const AppSettings();
  IVideoSource? _source;
  StreamSubscription<CameraFrame>? _frames;
  Timer? _pollTimer;
  GeoPosition? _lastPosition;
  DateTime? _mutedUntil;
  DateTime? _dialogDeadline;
  bool _voiceReady = false;
  bool _gpsWarned = false;
  bool _resumeOnReturn = false;
  int _failures = 0;
  int _speaking = 0;
  int _loopId = 0;
  int _listenGeneration = 0;
  int _windowCount = 0;
  DateTime? _windowStart;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    if (autoStart) {
      unawaited(startScan());
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_shutdown());
    super.onClose();
  }

  Future<void> _shutdown() async {
    await stopScan();
    await _detector.dispose();
  }

  /// Si la app pasa a segundo plano se libera la cámara y al volver se
  /// reanuda el escáner.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused &&
        state.value == ScanState.scanning) {
      _resumeOnReturn = true;
      unawaited(stopScan());
    } else if (lifecycle == AppLifecycleState.resumed && _resumeOnReturn) {
      _resumeOnReturn = false;
      unawaited(startScan());
    }
  }

  // ----------------------------------------------------------- Inicio (HU02)

  /// Inicia el escáner: permisos, modelo, cámara, GPS y comandos de voz.
  Future<void> startScan() async {
    if (state.value == ScanState.starting ||
        state.value == ScanState.scanning) {
      return;
    }
    final began = _clock();
    state.value = ScanState.starting;
    status.value = 'Iniciando el escáner…';
    _config = await _settings.load();
    await _speech.configure(rate: _config.speechRate, volume: _config.volume);

    // CA2: explica para qué se usa el permiso antes de pedirlo.
    if (!await _ensurePermission(AppPermission.camera)) {
      _fail('Sin permiso de cámara');
      await _say(cameraDeniedMessage);
      return;
    }
    try {
      await _detector.load();
    } on Object {
      _fail('El modelo no se pudo cargar');
      await _say(detectionFailedMessage);
      return;
    }
    final VideoSourceChoice choice;
    final Stream<CameraFrame> frames;
    try {
      choice = await _sources.choose(_config.videoSource);
      frames = await choice.source.start();
    } on Object {
      _fail('No se pudo abrir la cámara');
      await _say(cameraFailedMessage);
      return;
    }
    if (state.value != ScanState.starting) {
      // Se detuvo mientras arrancaba.
      await choice.source.stop();
      return;
    }
    _source = choice.source;
    _resetSession();
    // Se cancela en stopScan().
    // ignore: cancel_subscriptions
    _frames = frames.listen((frame) => unawaited(processFrame(frame)));
    await _wakelock.enable();
    state.value = ScanState.scanning;
    status.value = 'Escáner activo';
    startupMs.value = _clock().difference(began).inMilliseconds;

    await _say(startedMessage);
    if (choice.fellBack) {
      await _say(usbFallbackMessage);
    }
    await _startLocation();
    if (listenForCommands) {
      await _startVoice();
    }
  }

  void _fail(String reason) {
    state.value = ScanState.failed;
    status.value = reason;
  }

  void _resetSession() {
    _gate.reset();
    _stability.reset();
    _alerts.reset();
    _monitor.reset();
    _lastZoneAttempt.clear();
    _failures = 0;
    _mutedUntil = null;
    muted.value = false;
    _gpsWarned = false;
    _windowCount = 0;
    _windowStart = null;
    dialog.value = ScannerDialog.none;
  }

  Future<bool> _ensurePermission(AppPermission permission) async {
    if (await _permissions.isGranted(permission)) {
      return true;
    }
    await _say(permissionReason(permission));
    return _permissions.request(permission);
  }

  // ------------------------------------------------------- Detener (HU09)

  /// Detiene la cámara, el GPS y los comandos de voz.
  Future<void> stopScan({bool announce = false}) async {
    final wasActive =
        state.value == ScanState.scanning || state.value == ScanState.starting;
    _loopId++;
    _listenGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
    dialog.value = ScannerDialog.none;
    if (wasActive) {
      state.value = ScanState.stopped;
      status.value = 'Escáner detenido';
    }
    final frames = _frames;
    _frames = null;
    await frames?.cancel();
    final source = _source;
    _source = null;
    await source?.stop();
    if (wasActive) {
      await _voice.stop();
      await _wakelock.disable();
    }
    if (announce) {
      await _say(stoppedMessage);
    }
  }

  // ------------------------------------------------ Cuadros (HU03 y HU04)

  /// Analiza un cuadro: detección, estabilidad, alerta y registro de zonas.
  @visibleForTesting
  Future<void> processFrame(CameraFrame frame) async {
    if (state.value != ScanState.scanning ||
        !_gate.tryAcquire(frame.capturedAt)) {
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
        _failures++;
        if (_failures == AppConstants.detectionFailuresToWarn) {
          status.value = 'Falla en la detección';
          unawaited(_say(detectionFailedMessage));
        }
        return;
      }
      if (state.value != ScanState.scanning) {
        return;
      }
      if (_failures >= AppConstants.detectionFailuresToWarn) {
        status.value = 'Escáner activo';
      }
      _failures = 0;
      final now = _clock();
      _updateRate(now);
      inferenceMs.value = result.inferenceMicros ~/ 1000;
      muted.value = _isMuted(now);

      final confirmed = _stability.update(result.detections);
      final decision = _alerts.decide(confirmed, now);
      if (decision != null) {
        _emit(decision, frame.capturedAt, now);
      }
      await _registerZones(confirmed, now);
    } finally {
      _gate.release();
    }
  }

  void _updateRate(DateTime now) {
    _windowCount++;
    final start = _windowStart ??= now;
    final elapsed = now.difference(start).inMilliseconds;
    if (elapsed >= 1000) {
      fps.value = _windowCount * 1000 / elapsed;
      _windowCount = 0;
      _windowStart = now;
    }
  }

  /// Voz, vibración e historial de una alerta (HU03, HU04, RF17).
  void _emit(AlertDecision decision, DateTime capturedAt, DateTime now) {
    final d = decision.detection;
    captureToAlertMs.value = now.difference(capturedAt).inMilliseconds;
    headline.value = decision.message;
    headlineProximity.value = d.proximity;

    final isMuted = _isMuted(now);
    // HU09 CA2: en silencio se mantiene la vibración de lo que está cerca.
    if (_config.vibration && (!isMuted || d.proximity == Proximity.near)) {
      unawaited(_haptics.play(decision.vibrationPattern));
    }
    if (!isMuted) {
      unawaited(_say(decision.message));
    }
    final position = _recentPosition(now);
    unawaited(
      _history.add(
        DetectionRecord(
          label: d.label,
          confidence: d.confidence,
          proximity: d.proximity,
          timestamp: now,
          lat: position?.latitude,
          lng: position?.longitude,
        ),
      ),
    );
  }

  /// Registro automático de zonas (HU06).
  Future<void> _registerZones(List<Detection> confirmed, DateTime now) async {
    for (final d in confirmed) {
      if (d.proximity != Proximity.near ||
          !ObstacleCatalog.createsZone(d.label)) {
        continue;
      }
      final key = ObstacleCatalog.normalize(d.label);
      final last = _lastZoneAttempt[key];
      if (last != null &&
          now.difference(last) < AppConstants.zoneRegistrationThrottle) {
        continue;
      }
      _lastZoneAttempt[key] = now;
      try {
        await _zoneService.registerDetection(
          d,
          _recentPosition(now),
          _config,
        );
      } on Object {
        // Un error al guardar no debe detener la detección (RNF05).
      }
    }
  }

  GeoPosition? _recentPosition(DateTime now) {
    final p = _lastPosition;
    if (p == null ||
        now.difference(p.timestamp) > AppConstants.positionMaxAge) {
      return null;
    }
    return p;
  }

  // ---------------------------------------------------- Zonas (HU08, GPS)

  Future<void> _startLocation() async {
    final allowed = await _ensurePermission(AppPermission.location);
    final ready = allowed && await _location.ensureReady();
    if (!ready) {
      _gpsWarned = true;
      await _say(noGpsMessage);
    }
    if (state.value == ScanState.scanning) {
      _pollTimer?.cancel();
      _pollTimer = _periodic(
        AppConstants.positionPollInterval,
        (_) => unawaited(pollZones()),
      );
    }
  }

  /// Consulta la posición y avisa si hay una zona registrada cerca (HU08).
  /// Se llama cada 3 s mientras el escáner está activo.
  Future<void> pollZones() async {
    if (state.value != ScanState.scanning) {
      return;
    }
    final position = await _location.current();
    final now = _clock();
    if (position == null ||
        position.accuracyM > AppConstants.maxAccuracyToWarnM) {
      // RNF05: sin GPS la detección continúa y se avisa una vez.
      if (!_gpsWarned) {
        _gpsWarned = true;
        if (!_isMuted(now)) {
          await _say(noGpsMessage);
        }
      }
      return;
    }
    _gpsWarned = false;
    _lastPosition = position;
    final warning = _monitor.check(position, await _zones.all(), now);
    if (warning != null && state.value == ScanState.scanning) {
      headline.value = warning.message;
      headlineProximity.value = null;
      // HU04 CA3: pulso largo, distinto a los de obstáculos.
      if (_config.vibration) {
        unawaited(_haptics.play(HapticPatterns.zone));
      }
      if (!_isMuted(now)) {
        await _say(warning.message);
      }
    }
  }

  // --------------------------------------------- Comandos y gestos (HU09)

  /// Repite el último aviso (comando «repetir» o doble toque).
  void repeatLast() {
    if (state.value != ScanState.scanning) {
      return;
    }
    final text = headline.value;
    unawaited(_say(text.isEmpty ? noAlertMessage : text));
  }

  /// Pausa la voz 10 s; la vibración de lo cercano continúa (HU09, CA2).
  void mute() {
    if (state.value != ScanState.scanning) {
      return;
    }
    unawaited(_say(mutedMessage));
    _mutedUntil = _clock().add(AppConstants.muteDuration);
    muted.value = true;
  }

  bool _isMuted(DateTime now) {
    final until = _mutedUntil;
    return until != null && now.isBefore(until);
  }

  /// Marca una zona de riesgo (comando «marcar zona» o pulsación de 2 s,
  /// HU07). Pregunta el tipo por voz.
  Future<void> markZone() async {
    if (state.value != ScanState.scanning ||
        dialog.value != ScannerDialog.none) {
      return;
    }
    if (!_voiceReady) {
      // Sin reconocimiento de voz se guarda como riesgo genérico.
      await chooseZoneType('other');
      return;
    }
    await _ask(ScannerDialog.zoneType, askZoneTypeMessage);
  }

  /// Tipo de riesgo elegido por voz o con los botones.
  Future<void> chooseZoneType(String type) async {
    dialog.value = ScannerDialog.none;
    final position = await _location.current();
    final result = await _zoneService.registerManual(type, position, _config);
    switch (result) {
      case ZoneCreated(:final zone) || ZoneIncremented(:final zone):
        if (_config.vibration) {
          unawaited(_haptics.play(HapticPatterns.zone));
        }
        await _say(zoneSavedMessage(zone.type));
      case ZoneSkipped():
        await _say(zoneNoGpsMessage);
    }
  }

  Future<void> cancelZone() async {
    dialog.value = ScannerDialog.none;
    await _say(zoneCanceledMessage);
  }

  /// Pide confirmación antes de detener (HU09, CA3).
  Future<void> requestStop() async {
    if (state.value != ScanState.scanning ||
        dialog.value != ScannerDialog.none) {
      return;
    }
    await _ask(ScannerDialog.confirmStop, askStopMessage);
  }

  Future<void> confirmStop(bool confirmed) async {
    dialog.value = ScannerDialog.none;
    if (confirmed) {
      await stopScan(announce: true);
    } else {
      await _say(continueMessage);
    }
  }

  Future<void> _ask(ScannerDialog kind, String question) async {
    dialog.value = kind;
    // La escucha en curso empezó antes de la pregunta: se descarta.
    _listenGeneration++;
    if (_voiceReady) {
      unawaited(_voice.stop());
    }
    _dialogDeadline = null;
    await _say(question);
    _dialogDeadline = _clock().add(AppConstants.manualZoneAnswerTimeout);
  }

  bool _expired(DateTime now) {
    final deadline = _dialogDeadline;
    return deadline != null && !now.isBefore(deadline);
  }

  /// Interpreta lo que dijo el usuario según la pregunta en curso. Un
  /// comando no reconocido no ejecuta ninguna acción (HU09, CA4).
  Future<void> handleVoice(String? text) async {
    final now = _clock();
    final command = text == null ? null : VoiceCommandParser.parseCommand(text);
    switch (dialog.value) {
      case ScannerDialog.none:
        switch (command) {
          case VoiceCommand.repeat:
            repeatLast();
          case VoiceCommand.mute:
            mute();
          case VoiceCommand.markZone:
            await markZone();
          case VoiceCommand.terminate:
            await requestStop();
          default:
            break;
        }
      case ScannerDialog.zoneType:
        if (command == VoiceCommand.cancel) {
          await cancelZone();
          return;
        }
        final type =
            text == null ? null : VoiceCommandParser.parseZoneType(text);
        if (type != null) {
          await chooseZoneType(type);
        } else if (_expired(now)) {
          // HU07 CA3: sin respuesta en 8 s no se guarda.
          await cancelZone();
        }
      case ScannerDialog.confirmStop:
        if (command == VoiceCommand.yes || command == VoiceCommand.terminate) {
          await confirmStop(true);
        } else if (command == VoiceCommand.no ||
            command == VoiceCommand.cancel ||
            _expired(now)) {
          await confirmStop(false);
        }
    }
  }

  Future<void> _startVoice() async {
    if (!await _ensurePermission(AppPermission.microphone)) {
      _voiceReady = false;
      await _say(noVoiceMessage);
      return;
    }
    _voiceReady = await _voice.init();
    if (!_voiceReady) {
      await _say(noVoiceMessage);
      return;
    }
    if (state.value == ScanState.scanning) {
      unawaited(_commandLoop(++_loopId));
    }
  }

  /// Escucha comandos mientras el escáner está activo. No escucha mientras
  /// la app habla, para no reconocer su propia voz.
  Future<void> _commandLoop(int id) async {
    while (id == _loopId && state.value == ScanState.scanning) {
      await _waitUntilSilent();
      if (id != _loopId || state.value != ScanState.scanning) {
        return;
      }
      final generation = _listenGeneration;
      final began = _clock();
      final timeout = dialog.value == ScannerDialog.none
          ? AppConstants.commandListenWindow
          : AppConstants.manualZoneAnswerTimeout;
      String? text;
      try {
        text = await _voice.listenOnce(timeout: timeout);
      } on Object {
        text = null;
      }
      if (id != _loopId || state.value != ScanState.scanning) {
        return;
      }
      if (generation == _listenGeneration) {
        await handleVoice(text);
      }
      // Si el reconocedor falla al instante, se espera un poco para no
      // ocupar el procesador.
      if (_clock().difference(began) < const Duration(milliseconds: 500)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _waitUntilSilent() async {
    final limit = _clock().add(const Duration(seconds: 6));
    while (_speaking > 0 && _clock().isBefore(limit)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _say(String text) async {
    _speaking++;
    try {
      await _speech.speak(text);
    } on Object {
      // Si la voz falla, la vibración y la pantalla siguen funcionando.
    } finally {
      _speaking--;
    }
  }
}
