import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Transformación de «letterbox»: la imagen vertical se escala sin deformarse
/// hasta caber en el cuadrado de entrada del modelo y se rellena con gris.
///
/// La versión preliminar estiraba la imagen al cuadrado, lo que deformaba los
/// obstáculos; aquí se conserva la proporción (numeral 4.3.8).
class LetterboxTransform {
  LetterboxTransform({
    required this.srcWidth,
    required this.srcHeight,
    required this.target,
  })  : assert(srcWidth > 0 && srcHeight > 0 && target > 0),
        scale = math.min(target / srcWidth, target / srcHeight) {
    contentWidth = (srcWidth * scale).round();
    contentHeight = (srcHeight * scale).round();
    padX = (target - contentWidth) ~/ 2;
    padY = (target - contentHeight) ~/ 2;
  }

  /// Ancho y alto de la imagen vertical de origen, en píxeles.
  final int srcWidth;
  final int srcHeight;

  /// Lado del cuadrado de entrada del modelo.
  final int target;
  final double scale;
  late final int contentWidth;
  late final int contentHeight;
  late final int padX;
  late final int padY;

  /// Convierte una caja normalizada en el espacio del modelo a una caja
  /// normalizada respecto a la imagen vertical de origen.
  Rect toSource(Rect modelBox) {
    double mapX(double v) => _unit((v * target - padX) / contentWidth);
    double mapY(double v) => _unit((v * target - padY) / contentHeight);
    return Rect.fromLTRB(
      mapX(modelBox.left),
      mapY(modelBox.top),
      mapX(modelBox.right),
      mapY(modelBox.bottom),
    );
  }

  static double _unit(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
}

/// Planos de un cuadro YUV 4:2:0 de la cámara de Android.
class YuvFrame {
  const YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  /// Dimensiones del sensor (normalmente horizontales).
  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
}

/// Gris de relleno usado por Ultralytics (114 / 255).
const double letterboxPadValue = 114 / 255;

/// Convierte un cuadro YUV 4:2:0 directamente a la entrada del modelo:
/// gira la imagen a vertical, aplica letterbox y normaliza a RGB entre 0 y 1.
///
/// Solo se calculan los `target × target` píxeles de salida (muestreo del
/// vecino más cercano), por lo que la conversión es rápida incluso en Dart y
/// se ejecuta en un hilo aislado (numeral 4.1.7, denegación de servicio).
///
/// [rotationDegrees] es la rotación horaria necesaria para dejar la imagen
/// vertical (0, 90, 180 o 270; en la cámara trasera suele ser 90).
Float32List yuv420ToModelInput(
  YuvFrame frame, {
  required int rotationDegrees,
  required int target,
  Float32List? reuse,
}) {
  final rotated = rotationDegrees == 90 || rotationDegrees == 270;
  final uprightW = rotated ? frame.height : frame.width;
  final uprightH = rotated ? frame.width : frame.height;
  final lb = LetterboxTransform(
    srcWidth: uprightW,
    srcHeight: uprightH,
    target: target,
  );
  final out = (reuse != null && reuse.length == target * target * 3)
      ? reuse
      : Float32List(target * target * 3);

  final w = frame.width;
  final h = frame.height;
  for (var ty = 0; ty < target; ty++) {
    for (var tx = 0; tx < target; tx++) {
      final o = (ty * target + tx) * 3;
      final cx = tx - lb.padX;
      final cy = ty - lb.padY;
      if (cx < 0 || cy < 0 || cx >= lb.contentWidth || cy >= lb.contentHeight) {
        out[o] = letterboxPadValue;
        out[o + 1] = letterboxPadValue;
        out[o + 2] = letterboxPadValue;
        continue;
      }
      // Coordenadas en la imagen vertical (centro del píxel).
      var ux = ((cx + 0.5) / lb.scale).floor();
      var uy = ((cy + 0.5) / lb.scale).floor();
      if (ux >= uprightW) {
        ux = uprightW - 1;
      }
      if (uy >= uprightH) {
        uy = uprightH - 1;
      }

      // Coordenadas en el sensor según la rotación.
      int sx;
      int sy;
      switch (rotationDegrees) {
        case 90:
          sx = uy;
          sy = h - 1 - ux;
        case 180:
          sx = w - 1 - ux;
          sy = h - 1 - uy;
        case 270:
          sx = w - 1 - uy;
          sy = ux;
        default:
          sx = ux;
          sy = uy;
      }

      final yy = frame.y[sy * frame.yRowStride + sx].toDouble();
      final uvIndex =
          (sy >> 1) * frame.uvRowStride + (sx >> 1) * frame.uvPixelStride;
      final uu = frame.u[uvIndex] - 128.0;
      final vv = frame.v[uvIndex] - 128.0;

      out[o] = _channel(yy + 1.370705 * vv);
      out[o + 1] = _channel(yy - 0.337633 * uu - 0.698001 * vv);
      out[o + 2] = _channel(yy + 1.732446 * uu);
    }
  }
  return out;
}

double _channel(double value) {
  if (value <= 0) {
    return 0.0;
  }
  if (value >= 255) {
    return 1.0;
  }
  return value / 255.0;
}
