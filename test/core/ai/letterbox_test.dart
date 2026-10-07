import 'dart:typed_data';
import 'dart:ui';

import 'package:eyesight_ai/core/ai/letterbox.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuadro YUV de [w] × [h] con luminancia [yValue] y croma neutra, y un
/// píxel marcado (luminancia 0) en ([markX], [markY]) del sensor.
YuvFrame frame(int w, int h, {int yValue = 255, int? markX, int? markY}) {
  final y = Uint8List(w * h)..fillRange(0, w * h, yValue);
  if (markX != null && markY != null) {
    y[markY * w + markX] = 0;
  }
  final uvW = (w + 1) ~/ 2;
  final uvH = (h + 1) ~/ 2;
  final u = Uint8List(uvW * uvH)..fillRange(0, uvW * uvH, 128);
  final v = Uint8List(uvW * uvH)..fillRange(0, uvW * uvH, 128);
  return YuvFrame(
    width: w,
    height: h,
    y: y,
    u: u,
    v: v,
    yRowStride: w,
    uvRowStride: uvW,
    uvPixelStride: 1,
  );
}

double pixel(Float32List img, int target, int x, int y, [int channel = 0]) =>
    img[(y * target + x) * 3 + channel];

void main() {
  group('LetterboxTransform', () {
    test('imagen vertical 810 × 1080 en 320: relleno lateral de 40 px', () {
      final lb =
          LetterboxTransform(srcWidth: 810, srcHeight: 1080, target: 320);
      expect(lb.contentWidth, 240);
      expect(lb.contentHeight, 320);
      expect(lb.padX, 40);
      expect(lb.padY, 0);
    });

    test('toSource devuelve la caja en coordenadas de la imagen original', () {
      final lb =
          LetterboxTransform(srcWidth: 810, srcHeight: 1080, target: 320);
      final r = lb.toSource(const Rect.fromLTRB(40 / 320, 0, 280 / 320, 1));
      expect(r.left, closeTo(0, 1e-9));
      expect(r.right, closeTo(1, 1e-9));
      expect(r.top, closeTo(0, 1e-9));
      expect(r.bottom, closeTo(1, 1e-9));
    });

    test('una caja dentro del relleno se recorta a los bordes', () {
      final lb =
          LetterboxTransform(srcWidth: 810, srcHeight: 1080, target: 320);
      final r = lb.toSource(const Rect.fromLTRB(0, 0.2, 0.05, 0.4));
      expect(r.left, 0);
      expect(r.right, 0);
    });
  });

  group('yuv420ToModelInput', () {
    test('Y=255 con croma neutra produce blanco y el relleno es gris 114', () {
      // Sensor 8 × 4 girado 90°: imagen vertical 4 × 8 → letterbox en 8.
      final out =
          yuv420ToModelInput(frame(8, 4), rotationDegrees: 90, target: 8);
      expect(out.length, 8 * 8 * 3);
      // Columnas 0-1 y 6-7 son relleno; 2-5 son contenido.
      expect(pixel(out, 8, 0, 3), closeTo(letterboxPadValue, 1e-6));
      expect(pixel(out, 8, 7, 3), closeTo(letterboxPadValue, 1e-6));
      for (var c = 0; c < 3; c++) {
        expect(pixel(out, 8, 3, 3, c), closeTo(1.0, 1e-6));
      }
    });

    test('rotación 0: el píxel marcado conserva su posición', () {
      final out = yuv420ToModelInput(
        frame(4, 4, markX: 1, markY: 2),
        rotationDegrees: 0,
        target: 4,
      );
      expect(pixel(out, 4, 1, 2), 0);
      expect(pixel(out, 4, 2, 1), closeTo(1, 1e-6));
    });

    test(
        'rotación 90: la esquina inferior izquierda del sensor queda arriba a la izquierda',
        () {
      // Sensor 4 × 4, marca en (0, 3). Girada 90° horaria queda en (0, 0).
      final out = yuv420ToModelInput(
        frame(4, 4, markX: 0, markY: 3),
        rotationDegrees: 90,
        target: 4,
      );
      expect(pixel(out, 4, 0, 0), 0);
    });

    test('rotación 180: la esquina superior izquierda queda abajo a la derecha',
        () {
      final out = yuv420ToModelInput(
        frame(4, 4, markX: 0, markY: 0),
        rotationDegrees: 180,
        target: 4,
      );
      expect(pixel(out, 4, 3, 3), 0);
    });

    test(
        'rotación 270: la esquina superior derecha queda arriba a la izquierda',
        () {
      final out = yuv420ToModelInput(
        frame(4, 4, markX: 3, markY: 0),
        rotationDegrees: 270,
        target: 4,
      );
      expect(pixel(out, 4, 0, 0), 0);
    });

    test('respeta el paso de píxel de la croma (formato semiplanar)', () {
      // U y V intercalados con paso 2, como en NV21/NV12.
      const w = 4;
      const h = 2;
      final y = Uint8List(w * h)..fillRange(0, w * h, 128);
      final uv = Uint8List(4)..setAll(0, [255, 128, 255, 128]);
      final f = YuvFrame(
        width: w,
        height: h,
        y: y,
        u: uv,
        v: Uint8List.sublistView(uv, 1),
        yRowStride: w,
        uvRowStride: 4,
        uvPixelStride: 2,
      );
      final out = yuv420ToModelInput(f, rotationDegrees: 0, target: 4);
      // U alto, V neutro: más azul que rojo.
      final r = pixel(out, 4, 0, 1, 0);
      final b = pixel(out, 4, 0, 1, 2);
      expect(b, greaterThan(r));
    });

    test('reutiliza el búfer cuando tiene el tamaño correcto', () {
      final buffer = Float32List(4 * 4 * 3);
      final out = yuv420ToModelInput(frame(4, 4),
          rotationDegrees: 0, target: 4, reuse: buffer);
      expect(identical(out, buffer), isTrue);
    });
  });
}
