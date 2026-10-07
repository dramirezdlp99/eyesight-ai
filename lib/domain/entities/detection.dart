import 'dart:ui' show Rect;

import 'proximity.dart';

/// Obstáculo detectado en un cuadro (diagrama de clases, numeral 4.3.6).
///
/// [box] está normalizada entre 0 y 1 respecto a la imagen vertical
/// (izquierda, arriba, derecha, abajo).
class Detection {
  const Detection({
    required this.label,
    required this.confidence,
    required this.box,
    this.proximity = Proximity.far,
    this.inPath = false,
  });

  /// Clave de la clase del modelo, por ejemplo `person` o `pothole`.
  final String label;
  final double confidence;
  final Rect box;
  final Proximity proximity;

  /// `true` si el obstáculo está en la franja de trayectoria (RF05).
  final bool inPath;

  double get centerX => box.center.dx;

  Detection copyWith({Proximity? proximity, bool? inPath}) => Detection(
        label: label,
        confidence: confidence,
        box: box,
        proximity: proximity ?? this.proximity,
        inPath: inPath ?? this.inPath,
      );

  @override
  bool operator ==(Object other) =>
      other is Detection &&
      other.label == label &&
      other.confidence == confidence &&
      other.box == box &&
      other.proximity == proximity &&
      other.inPath == inPath;

  @override
  int get hashCode => Object.hash(label, confidence, box, proximity, inPath);

  @override
  String toString() =>
      'Detection($label, ${confidence.toStringAsFixed(2)}, ${proximity.name}, inPath: $inPath)';
}
