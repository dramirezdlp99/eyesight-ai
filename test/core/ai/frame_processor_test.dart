import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eyesight_ai/core/ai/frame_processor.dart';
import 'package:eyesight_ai/core/ai/letterbox.dart';
import 'package:eyesight_ai/core/ai/obstacle_catalog.dart';
import 'package:eyesight_ai/core/ai/tensor_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuadro YUV gris del tamaño del sensor.
YuvFrame grayFrame(int w, int h) {
  final uvW = (w + 1) ~/ 2;
  final uvH = (h + 1) ~/ 2;
  return YuvFrame(
    width: w,
    height: h,
    y: Uint8List(w * h)..fillRange(0, w * h, 128),
    u: Uint8List(uvW * uvH)..fillRange(0, uvW * uvH, 128),
    v: Uint8List(uvW * uvH)..fillRange(0, uvW * uvH, 128),
    yRowStride: w,
    uvRowStride: uvW,
    uvPixelStride: 1,
  );
}

void main() {
  late Uint8List modelOutput;
  late List<String> labels;
  late Map<String, dynamic> expected;

  setUpAll(() {
    modelOutput =
        File('test/fixtures/bus_yolov8n_output.f32').readAsBytesSync();
    labels = File('test/fixtures/coco80_labels.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expected =
        jsonDecode(File('test/fixtures/bus_expected.json').readAsStringSync())
            as Map<String, dynamic>;
  });

  const io = ModelIO(
    inputSize: 320,
    inputKind: TensorKind.float32,
    outputShape: [1, 84, 2100],
    outputKind: TensorKind.float32,
  );

  test('canal completo con la salida real: rotación 90°, NMS y letterbox', () {
    Uint8List? received;
    final processor = FrameProcessor(
      io: io,
      labels: labels,
      run: (input) {
        received = input;
        return modelOutput;
      },
    );
    // Sensor horizontal 1080 × 810; girado 90° queda vertical 810 × 1080,
    // las mismas dimensiones de bus.jpg con las que se generó la referencia.
    final result = processor.process(
      grayFrame(1080, 810),
      rotationDegrees: 90,
      confidenceThreshold: 0.5,
    );

    expect(received!.length, io.inputByteLength);
    final ref =
        (expected['detections'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(result.boxes.length, ref.length);
    for (var i = 0; i < ref.length; i++) {
      final want = (ref[i]['source_box'] as List<dynamic>).cast<num>();
      expect(result.boxes[i].label, ref[i]['label']);
      expect(result.boxes[i].box.left, closeTo(want[0].toDouble(), 1e-4));
      expect(result.boxes[i].box.top, closeTo(want[1].toDouble(), 1e-4));
      expect(result.boxes[i].box.right, closeTo(want[2].toDouble(), 1e-4));
      expect(result.boxes[i].box.bottom, closeTo(want[3].toDouble(), 1e-4));
    }
    expect(result.totalMicros, greaterThanOrEqualTo(result.inferenceMicros));
  });

  test('solo entrega clases del catálogo de obstáculos', () {
    final processor =
        FrameProcessor(io: io, labels: labels, run: (_) => modelOutput);
    final result = processor.process(
      grayFrame(1080, 810),
      rotationDegrees: 90,
      confidenceThreshold: 0.25,
    );
    expect(result.boxes, isNotEmpty);
    for (final b in result.boxes) {
      expect(ObstacleCatalog.isObstacle(b.label), isTrue, reason: b.label);
    }
  });

  test('la forma de salida debe corresponder a las etiquetas', () {
    expect(
      () => FrameProcessor(
          io: io, labels: const ['solo una'], run: (_) => modelOutput),
      throwsArgumentError,
    );
  });
}
