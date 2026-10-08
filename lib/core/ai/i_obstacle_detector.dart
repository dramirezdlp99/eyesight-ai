import '../../domain/entities/detection.dart';
import 'camera_frame.dart';

/// Detecciones de un cuadro con sus tiempos (diagrama de clases, RNF01).
class FrameDetections {
  const FrameDetections({
    required this.detections,
    required this.capturedAt,
    required this.inferenceMicros,
    required this.totalMicros,
  });

  final List<Detection> detections;
  final DateTime capturedAt;

  /// Solo la ejecución del modelo (meta: menos de 100 ms).
  final int inferenceMicros;

  /// Preprocesamiento, inferencia y decodificación.
  final int totalMicros;
}

/// Puerto del detector de obstáculos (patrón Strategy, numeral 4.3.4).
abstract interface class IObstacleDetector {
  bool get isReady;

  /// Carga y verifica el modelo. Lanza una excepción si no es posible.
  Future<void> load();

  Future<FrameDetections> detect(
    CameraFrame frame, {
    required double confidenceThreshold,
  });

  Future<void> dispose();
}
