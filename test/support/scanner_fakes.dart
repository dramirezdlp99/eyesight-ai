import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:eyesight_ai/core/ai/camera_frame.dart';
import 'package:eyesight_ai/core/ai/i_obstacle_detector.dart';
import 'package:eyesight_ai/core/ai/letterbox.dart';
import 'package:eyesight_ai/core/device/i_video_source.dart';
import 'package:eyesight_ai/core/device/wakelock_service.dart';
import 'package:eyesight_ai/domain/entities/detection.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';

/// Cuadro de video vacío capturado en [at].
CameraFrame frameAt(DateTime at) => CameraFrame(
      yuv: YuvFrame(
        width: 4,
        height: 4,
        y: Uint8List(16),
        u: Uint8List(4),
        v: Uint8List(4),
        yRowStride: 4,
        uvRowStride: 2,
        uvPixelStride: 1,
      ),
      rotationDegrees: 90,
      capturedAt: at,
    );

/// Detector falso: devuelve, en orden, las detecciones programadas.
class FakeDetector implements IObstacleDetector {
  final Queue<List<Detection>> _results = Queue();
  bool loaded = false;
  bool failOnLoad = false;
  bool failOnDetect = false;
  int disposed = 0;
  double? lastThreshold;

  /// Programa el resultado del siguiente cuadro.
  void next(List<Detection> detections) => _results.add(detections);

  @override
  bool get isReady => loaded;

  @override
  Future<void> load() async {
    if (failOnLoad) {
      throw StateError('modelo dañado');
    }
    loaded = true;
  }

  @override
  Future<FrameDetections> detect(
    CameraFrame frame, {
    required double confidenceThreshold,
  }) async {
    lastThreshold = confidenceThreshold;
    if (failOnDetect) {
      throw StateError('falla');
    }
    return FrameDetections(
      detections: _results.isEmpty ? const [] : _results.removeFirst(),
      capturedAt: frame.capturedAt,
      inferenceMicros: 40000,
      totalMicros: 60000,
    );
  }

  @override
  Future<void> dispose() async {
    disposed++;
    loaded = false;
  }
}

/// Fuente de video falsa: la prueba decide si está disponible.
class FakeVideoSource implements IVideoSource {
  FakeVideoSource({this.kind = VideoSourceKind.phone, this.available = true});

  @override
  final VideoSourceKind kind;
  bool available;
  bool failOnStart = false;
  int starts = 0;
  int stops = 0;
  StreamController<CameraFrame>? _controller;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Stream<CameraFrame>> start() async {
    if (failOnStart) {
      throw StateError('sin cámara');
    }
    starts++;
    // Se cierra en stop().
    // ignore: close_sinks
    final controller = StreamController<CameraFrame>();
    _controller = controller;
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
    final controller = _controller;
    _controller = null;
    // No se espera close(): dentro de testWidgets ese futuro puede no
    // completarse nunca y la prueba quedaría bloqueada.
    if (controller != null) {
      unawaited(controller.close());
    }
  }
}

class FakeWakelock implements IWakelock {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}

/// Temporizador periódico falso: guarda la función para llamarla a mano.
class FakePeriodic {
  final List<void Function(Timer)> callbacks = [];
  final List<FakeTimer> timers = [];

  Timer call(Duration period, void Function(Timer) callback) {
    callbacks.add(callback);
    final timer = FakeTimer();
    timers.add(timer);
    return timer;
  }

  bool get active => timers.any((t) => t.isActive);
}

class FakeTimer implements Timer {
  bool _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
