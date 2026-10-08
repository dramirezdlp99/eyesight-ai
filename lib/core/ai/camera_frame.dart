import 'letterbox.dart';

/// Cuadro de video listo para analizar.
class CameraFrame {
  const CameraFrame({
    required this.yuv,
    required this.rotationDegrees,
    required this.capturedAt,
  });

  final YuvFrame yuv;

  /// Rotación horaria para dejar la imagen vertical (0, 90, 180 o 270).
  final int rotationDegrees;

  /// Momento de la captura: inicio de la medición de captura a alerta (RNF02).
  final DateTime capturedAt;
}
