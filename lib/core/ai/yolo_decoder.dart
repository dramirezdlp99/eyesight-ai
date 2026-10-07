import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../config/app_constants.dart';

/// Disposición del tensor de salida de YOLOv8.
///
/// La exportación de Ultralytics a LiteRT entrega `[1, 4 + clases, N]`
/// (canales primero); algunos convertidores la entregan transpuesta,
/// `[1, N, 4 + clases]`.
class YoloOutputLayout {
  const YoloOutputLayout({
    required this.numClasses,
    required this.numCandidates,
    required this.channelsFirst,
  });

  /// Deduce la disposición a partir de la forma del tensor y del número de
  /// etiquetas. Lanza [ArgumentError] si la forma no corresponde a YOLOv8.
  factory YoloOutputLayout.fromShape(List<int> shape, int numClasses) {
    if (shape.length != 3 || shape[0] != 1) {
      throw ArgumentError('Forma de salida no soportada: $shape');
    }
    final channels = 4 + numClasses;
    if (shape[1] == channels) {
      return YoloOutputLayout(
        numClasses: numClasses,
        numCandidates: shape[2],
        channelsFirst: true,
      );
    }
    if (shape[2] == channels) {
      return YoloOutputLayout(
        numClasses: numClasses,
        numCandidates: shape[1],
        channelsFirst: false,
      );
    }
    throw ArgumentError(
      'La salida $shape no coincide con $numClasses etiquetas (4 + clases)',
    );
  }

  final int numClasses;
  final int numCandidates;
  final bool channelsFirst;

  int get length => (4 + numClasses) * numCandidates;

  /// Valor del canal [c] para el candidato [i].
  int indexOf(int c, int i) =>
      channelsFirst ? c * numCandidates + i : i * (4 + numClasses) + c;
}

/// Detección cruda del modelo, con la caja normalizada en el espacio de
/// entrada del modelo (imagen de 320 × 320 con bordes de relleno).
class RawDetection {
  const RawDetection({
    required this.classIndex,
    required this.label,
    required this.score,
    required this.box,
  });

  final int classIndex;
  final String label;
  final double score;
  final Rect box;

  @override
  String toString() =>
      'RawDetection($label, ${score.toStringAsFixed(3)}, $box)';
}

/// Decodifica la salida de YOLOv8n y aplica supresión de no máximos (NMS).
///
/// Corrige dos fallas de la versión preliminar: ahora se leen las cajas
/// delimitadoras y se aplica NMS por clase (numeral 4.3.8).
class YoloDecoder {
  const YoloDecoder({
    required this.labels,
    this.iouThreshold = AppConstants.nmsIouThreshold,
    this.maxDetections = AppConstants.maxDetectionsPerFrame,
    this.inputSize = AppConstants.modelInputSize,
  });

  final List<String> labels;
  final double iouThreshold;
  final int maxDetections;
  final int inputSize;

  /// [output] es el tensor plano. Solo se conservan los candidatos cuya mejor
  /// clase supera [confidenceThreshold] y cuya etiqueta acepta [accept].
  List<RawDetection> decode(
    List<double> output,
    YoloOutputLayout layout, {
    required double confidenceThreshold,
    bool Function(String label)? accept,
  }) {
    if (output.length < layout.length) {
      throw ArgumentError(
        'Salida de ${output.length} valores; se esperaban ${layout.length}',
      );
    }
    if (layout.numClasses != labels.length) {
      throw ArgumentError(
        'El modelo tiene ${layout.numClasses} clases y hay ${labels.length} etiquetas',
      );
    }
    final n = layout.numCandidates;

    // Las exportaciones recientes entregan coordenadas normalizadas (0 a 1);
    // otras, en píxeles. Se detecta la escala con el mayor valor de caja.
    var maxCoord = 0.0;
    for (var i = 0; i < n; i++) {
      for (var c = 0; c < 4; c++) {
        final v = output[layout.indexOf(c, i)];
        if (v > maxCoord) {
          maxCoord = v;
        }
      }
    }
    final scale = maxCoord > 1.5 ? 1 / inputSize : 1.0;

    final candidates = <RawDetection>[];
    for (var i = 0; i < n; i++) {
      // Mejor clase del candidato (primera en caso de empate, como argmax).
      var best = 0;
      var bestScore = output[layout.indexOf(4, i)];
      for (var k = 1; k < layout.numClasses; k++) {
        final s = output[layout.indexOf(4 + k, i)];
        if (s > bestScore) {
          bestScore = s;
          best = k;
        }
      }
      if (bestScore < confidenceThreshold) {
        continue;
      }
      final label = labels[best];
      if (accept != null && !accept(label)) {
        continue;
      }
      final cx = output[layout.indexOf(0, i)] * scale;
      final cy = output[layout.indexOf(1, i)] * scale;
      final w = output[layout.indexOf(2, i)] * scale;
      final h = output[layout.indexOf(3, i)] * scale;
      if (w <= 0 || h <= 0) {
        continue;
      }
      candidates.add(
        RawDetection(
          classIndex: best,
          label: label,
          score: bestScore,
          box: Rect.fromLTRB(
            _unit(cx - w / 2),
            _unit(cy - h / 2),
            _unit(cx + w / 2),
            _unit(cy + h / 2),
          ),
        ),
      );
    }
    return nonMaxSuppression(candidates, iouThreshold, maxDetections);
  }

  static double _unit(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

  /// NMS voraz por clase: conserva la caja de mayor puntaje y elimina las de
  /// la misma clase que se superponen más de [iouThreshold].
  static List<RawDetection> nonMaxSuppression(
    List<RawDetection> candidates,
    double iouThreshold,
    int maxDetections,
  ) {
    final sorted = [...candidates]..sort((a, b) => b.score.compareTo(a.score));
    final kept = <RawDetection>[];
    for (final c in sorted) {
      var suppressed = false;
      for (final k in kept) {
        if (k.classIndex == c.classIndex && iou(k.box, c.box) > iouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) {
        kept.add(c);
        if (kept.length >= maxDetections) {
          break;
        }
      }
    }
    return kept;
  }

  /// Intersección sobre la unión de dos cajas (Tabla de métricas, numeral 2.2.1).
  static double iou(Rect a, Rect b) {
    final iw = math.min(a.right, b.right) - math.max(a.left, b.left);
    final ih = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    if (iw <= 0 || ih <= 0) {
      return 0.0;
    }
    final inter = iw * ih;
    final union = a.width * a.height + b.width * b.height - inter;
    return union <= 0 ? 0.0 : inter / union;
  }
}
