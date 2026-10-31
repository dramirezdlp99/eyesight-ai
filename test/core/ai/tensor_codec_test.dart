import 'dart:typed_data';

import 'package:eyesight_ai/core/ai/tensor_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const floatIO = ModelIO(
    inputSize: 2,
    inputKind: TensorKind.float32,
    outputShape: [1, 6, 1],
    outputKind: TensorKind.float32,
  );

  test('entrada float32: los bytes son la imagen tal cual', () {
    final image = Float32List.fromList(List.generate(12, (i) => i / 12));
    final bytes = TensorCodec.encodeInput(image, floatIO);
    expect(bytes.length, floatIO.inputByteLength);
    expect(bytes.buffer.asFloat32List(bytes.offsetInBytes, 12), image);
  });

  test('entrada int8: q = round(x / escala) + punto cero, saturado', () {
    const io = ModelIO(
      inputSize: 1,
      inputKind: TensorKind.int8,
      inputScale: 1 / 255,
      inputZeroPoint: -128,
      outputShape: [1, 6, 1],
      outputKind: TensorKind.int8,
    );
    final bytes =
        TensorCodec.encodeInput(Float32List.fromList([0, 0.5, 1]), io);
    final q = Int8List.sublistView(bytes);
    expect(q, [-128, 0, 127]);
    expect(io.inputByteLength, 3);
  });

  test('entrada uint8 con punto cero 0', () {
    const io = ModelIO(
      inputSize: 1,
      inputKind: TensorKind.uint8,
      inputScale: 1 / 255,
      outputShape: [1, 6, 1],
      outputKind: TensorKind.uint8,
    );
    expect(TensorCodec.encodeInput(Float32List.fromList([0, 1, 2]), io),
        [0, 255, 255]);
  });

  test('salida float32 en little endian', () {
    final values = Float32List.fromList([0.25, -1.5, 3]);
    final raw = values.buffer.asUint8List();
    expect(TensorCodec.decodeOutput(raw, floatIO), values);
  });

  test('salida int8: x = (q − punto cero) × escala', () {
    const io = ModelIO(
      inputSize: 1,
      inputKind: TensorKind.int8,
      outputShape: [1, 6, 1],
      outputKind: TensorKind.int8,
      outputScale: 0.5,
      outputZeroPoint: -10,
    );
    final raw = Int8List.fromList([-10, 0, 10]).buffer.asUint8List();
    expect(TensorCodec.decodeOutput(raw, io), [0.0, 5.0, 10.0]);
  });

  test('salida uint8', () {
    const io = ModelIO(
      inputSize: 1,
      inputKind: TensorKind.uint8,
      outputShape: [1, 6, 1],
      outputKind: TensorKind.uint8,
      outputScale: 0.1,
      outputZeroPoint: 100,
    );
    final out = TensorCodec.decodeOutput(Uint8List.fromList([100, 110]), io);
    expect(out[0], closeTo(0, 1e-6));
    expect(out[1], closeTo(1, 1e-6));
  });

  test('forma de entrada: canales al final o primero', () {
    expect(ModelIO.inputLayout([1, 320, 320, 3]),
        (size: 320, channelsFirst: false));
    expect(ModelIO.inputLayout([1, 3, 480, 480]),
        (size: 480, channelsFirst: true));
    expect(() => ModelIO.inputLayout([1, 480, 480]), throwsArgumentError);
    expect(() => ModelIO.inputLayout([1, 4, 480, 5]), throwsArgumentError);
  });

  test('reordena RGB intercalado a un plano por canal', () {
    // Imagen 2 × 2: píxel p tiene R = p, G = 10 + p, B = 20 + p.
    final hwc = Float32List.fromList([
      for (var p = 0; p < 4; p++) ...[p.toDouble(), 10.0 + p, 20.0 + p],
    ]);
    final chw = TensorCodec.toChannelsFirst(hwc, 2);
    expect(chw, [0, 1, 2, 3, 10, 11, 12, 13, 20, 21, 22, 23]);
    final reused = TensorCodec.toChannelsFirst(hwc, 2, reuse: chw);
    expect(identical(reused, chw), isTrue);
  });
}
