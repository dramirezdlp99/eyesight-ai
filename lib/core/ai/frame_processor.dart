import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'letterbox.dart';
import 'obstacle_catalog.dart';
import 'tensor_codec.dart';
import 'yolo_decoder.dart';

/// Obstáculo encontrado en un cuadro, con la caja normalizada respecto a la
/// imagen vertical de la cámara.
class FrameBox {
  const FrameBox({required this.label, required this.score, required this.box});

  final String label;
  final double score;
  final Rect box;
}

/// Resultado de procesar un cuadro y tiempos de cada etapa (RNF01).
class ProcessedFrame {
  const ProcessedFrame({
    required this.boxes,
    required this.preprocessMicros,
    required this.inferenceMicros,
    required this.postprocessMicros,
  });

  final List<FrameBox> boxes;
  final int preprocessMicros;
  final int inferenceMicros;
  final int postprocessMicros;

  int get totalMicros => preprocessMicros + inferenceMicros + postprocessMicros;
}

/// Ejecuta el modelo sobre los bytes de entrada y devuelve los de salida.
typedef TensorRunner = Uint8List Function(Uint8List input);

/// Canal completo de un cuadro: YUV → entrada del modelo → inferencia →
/// decodificación con NMS → cajas en coordenadas de la imagen vertical.
///
/// Es independiente de LiteRT: la inferencia se recibe como [TensorRunner],
/// lo que permite probar todo el canal con la salida real del modelo.
class FrameProcessor {
  FrameProcessor({
    required this.io,
    required List<String> labels,
    required TensorRunner run,
  })  : _run = run,
        _decoder = YoloDecoder(labels: labels, inputSize: io.inputSize),
        _layout = YoloOutputLayout.fromShape(io.outputShape, labels.length);

  final ModelIO io;
  final TensorRunner _run;
  final YoloDecoder _decoder;
  final YoloOutputLayout _layout;
  Float32List? _buffer;

  ProcessedFrame process(
    YuvFrame frame, {
    required int rotationDegrees,
    required double confidenceThreshold,
  }) {
    final sw = Stopwatch()..start();
    final image = yuv420ToModelInput(
      frame,
      rotationDegrees: rotationDegrees,
      target: io.inputSize,
      reuse: _buffer,
    );
    _buffer = image;
    final input = TensorCodec.encodeInput(image, io);
    final pre = sw.elapsedMicroseconds;

    final raw = _run(input);
    final inf = sw.elapsedMicroseconds - pre;

    final output = TensorCodec.decodeOutput(raw, io);
    final detections = _decoder.decode(
      output,
      _layout,
      confidenceThreshold: confidenceThreshold,
      accept: ObstacleCatalog.isObstacle,
    );
    final rotated = rotationDegrees == 90 || rotationDegrees == 270;
    final lb = LetterboxTransform(
      srcWidth: rotated ? frame.height : frame.width,
      srcHeight: rotated ? frame.width : frame.height,
      target: io.inputSize,
    );
    final boxes = [
      for (final d in detections)
        FrameBox(label: d.label, score: d.score, box: lb.toSource(d.box)),
    ];
    final post = sw.elapsedMicroseconds - pre - inf;
    return ProcessedFrame(
      boxes: boxes,
      preprocessMicros: pre,
      inferenceMicros: inf,
      postprocessMicros: post,
    );
  }
}
