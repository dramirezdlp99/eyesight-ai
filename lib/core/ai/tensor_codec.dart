import 'dart:typed_data';

/// Tipo numérico de un tensor de entrada o salida del modelo.
///
/// El modelo preentrenado usa `float32`; el modelo exportado con cuantización
/// INT8 puede usar `int8` o `uint8` en la entrada y la salida (numeral 2.2.2).
enum TensorKind { float32, int8, uint8 }

/// Descripción de la entrada y la salida del modelo cargado.
class ModelIO {
  const ModelIO({
    required this.inputSize,
    required this.inputKind,
    required this.outputShape,
    required this.outputKind,
    this.inputScale = 1,
    this.inputZeroPoint = 0,
    this.outputScale = 1,
    this.outputZeroPoint = 0,
  });

  final int inputSize;
  final TensorKind inputKind;
  final double inputScale;
  final int inputZeroPoint;
  final List<int> outputShape;
  final TensorKind outputKind;
  final double outputScale;
  final int outputZeroPoint;

  int get inputByteLength {
    final values = inputSize * inputSize * 3;
    return inputKind == TensorKind.float32 ? values * 4 : values;
  }

  @override
  String toString() =>
      'ModelIO(entrada ${inputKind.name} $inputSize, salida ${outputKind.name} $outputShape)';
}

/// Conversión entre la imagen normalizada y los bytes de los tensores.
abstract final class TensorCodec {
  /// Codifica la imagen (valores de 0 a 1) en los bytes de entrada.
  /// En modelos cuantizados: q = round(x / escala) + punto_cero.
  static Uint8List encodeInput(Float32List image, ModelIO io) {
    switch (io.inputKind) {
      case TensorKind.float32:
        return image.buffer
            .asUint8List(image.offsetInBytes, image.lengthInBytes);
      case TensorKind.int8:
        final out = Int8List(image.length);
        for (var i = 0; i < image.length; i++) {
          out[i] = _clamp(
              (image[i] / io.inputScale).round() + io.inputZeroPoint,
              -128,
              127);
        }
        return out.buffer.asUint8List();
      case TensorKind.uint8:
        final out = Uint8List(image.length);
        for (var i = 0; i < image.length; i++) {
          out[i] = _clamp(
              (image[i] / io.inputScale).round() + io.inputZeroPoint, 0, 255);
        }
        return out;
    }
  }

  /// Decodifica los bytes de salida a valores reales.
  /// En modelos cuantizados: x = (q − punto_cero) × escala.
  static Float32List decodeOutput(Uint8List raw, ModelIO io) {
    switch (io.outputKind) {
      case TensorKind.float32:
        final data = ByteData.sublistView(raw);
        final out = Float32List(raw.length ~/ 4);
        for (var i = 0; i < out.length; i++) {
          out[i] = data.getFloat32(i * 4, Endian.little);
        }
        return out;
      case TensorKind.int8:
        final values = Int8List.sublistView(raw);
        final out = Float32List(values.length);
        for (var i = 0; i < values.length; i++) {
          out[i] = (values[i] - io.outputZeroPoint) * io.outputScale;
        }
        return out;
      case TensorKind.uint8:
        final out = Float32List(raw.length);
        for (var i = 0; i < raw.length; i++) {
          out[i] = (raw[i] - io.outputZeroPoint) * io.outputScale;
        }
        return out;
    }
  }

  static int _clamp(int v, int min, int max) =>
      v < min ? min : (v > max ? max : v);
}
