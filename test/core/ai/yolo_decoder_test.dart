import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:eyesight_ai/core/ai/letterbox.dart';
import 'package:eyesight_ai/core/ai/obstacle_catalog.dart';
import 'package:eyesight_ai/core/ai/yolo_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Construye una salida sintética de 2 clases y 3 candidatos.
/// Candidatos: [cx, cy, w, h, puntaje_persona, puntaje_poste].
List<double> synthetic({required bool channelsFirst, double scale = 1}) {
  const candidates = [
    [0.50, 0.50, 0.20, 0.40, 0.90, 0.10],
    [0.51, 0.50, 0.20, 0.40, 0.80, 0.05], // se superpone con el primero
    [0.20, 0.80, 0.10, 0.10, 0.10, 0.70],
  ];
  const n = 3;
  const channels = 6;
  final out = List<double>.filled(n * channels, 0);
  for (var i = 0; i < n; i++) {
    for (var c = 0; c < channels; c++) {
      final v = candidates[i][c] * (c < 4 ? scale : 1);
      out[channelsFirst ? c * n + i : i * channels + c] = v;
    }
  }
  return out;
}

void main() {
  const labels = ['person', 'pole'];
  const decoder = YoloDecoder(labels: labels);

  group('YoloOutputLayout', () {
    test('reconoce la salida [1, 84, 2100] de Ultralytics', () {
      final l = YoloOutputLayout.fromShape([1, 84, 2100], 80);
      expect(l.channelsFirst, isTrue);
      expect(l.numCandidates, 2100);
      expect(l.length, 84 * 2100);
    });

    test('reconoce la salida transpuesta [1, 2100, 84]', () {
      final l = YoloOutputLayout.fromShape([1, 2100, 84], 80);
      expect(l.channelsFirst, isFalse);
      expect(l.numCandidates, 2100);
    });

    test('rechaza formas que no corresponden a las etiquetas', () {
      expect(() => YoloOutputLayout.fromShape([1, 84, 2100], 6),
          throwsArgumentError);
      expect(() => YoloOutputLayout.fromShape([1, 10], 6), throwsArgumentError);
    });
  });

  group('decodificación y NMS', () {
    for (final channelsFirst in [true, false]) {
      test('lee cajas y aplica NMS (canales primero: $channelsFirst)', () {
        final layout = YoloOutputLayout.fromShape(
          channelsFirst ? [1, 6, 3] : [1, 3, 6],
          2,
        );
        final out = decoder.decode(
          synthetic(channelsFirst: channelsFirst),
          layout,
          confidenceThreshold: 0.5,
        );
        expect(out.map((d) => d.label), ['person', 'pole']);
        expect(out[0].score, closeTo(0.9, 1e-9));
        expect(out[0].box.left, closeTo(0.40, 1e-9));
        expect(out[0].box.top, closeTo(0.30, 1e-9));
        expect(out[0].box.right, closeTo(0.60, 1e-9));
        expect(out[0].box.bottom, closeTo(0.70, 1e-9));
      });
    }

    test('acepta coordenadas en píxeles y las normaliza', () {
      final layout = YoloOutputLayout.fromShape([1, 6, 3], 2);
      final out = decoder.decode(
        synthetic(channelsFirst: true, scale: 320),
        layout,
        confidenceThreshold: 0.5,
      );
      expect(out[0].box.left, closeTo(0.40, 1e-9));
    });

    test('filtra por umbral y por etiqueta aceptada', () {
      final layout = YoloOutputLayout.fromShape([1, 6, 3], 2);
      final high = decoder.decode(synthetic(channelsFirst: true), layout,
          confidenceThreshold: 0.85);
      expect(high.map((d) => d.label), ['person']);
      final onlyPole = decoder.decode(
        synthetic(channelsFirst: true),
        layout,
        confidenceThreshold: 0.5,
        accept: (label) => label == 'pole',
      );
      expect(onlyPole.map((d) => d.label), ['pole']);
    });

    test('NMS no suprime cajas de clases distintas', () {
      const a = RawDetection(
          classIndex: 0,
          label: 'person',
          score: 0.9,
          box: Rect.fromLTRB(0, 0, 1, 1));
      const b = RawDetection(
          classIndex: 1,
          label: 'pole',
          score: 0.8,
          box: Rect.fromLTRB(0, 0, 1, 1));
      expect(YoloDecoder.nonMaxSuppression([a, b], 0.45, 20).length, 2);
    });

    test('IoU de cajas iguales, disjuntas y a medias', () {
      const r = Rect.fromLTRB(0, 0, 1, 1);
      expect(YoloDecoder.iou(r, r), 1);
      expect(YoloDecoder.iou(r, const Rect.fromLTRB(2, 2, 3, 3)), 0);
      expect(YoloDecoder.iou(r, const Rect.fromLTRB(0.5, 0, 1.5, 1)),
          closeTo(1 / 3, 1e-9));
    });

    test('error claro si la salida es más corta de lo esperado', () {
      final layout = YoloOutputLayout.fromShape([1, 6, 3], 2);
      expect(() => decoder.decode([0, 1], layout, confidenceThreshold: 0.5),
          throwsArgumentError);
    });
  });

  group('modelo real YOLOv8n (COCO) sobre bus.jpg', () {
    late List<double> output;
    late List<String> coco;
    late Map<String, dynamic> expected;

    setUpAll(() {
      final bytes =
          File('test/fixtures/bus_yolov8n_output.f32').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      output = List<double>.generate(
        bytes.length ~/ 4,
        (i) => data.getFloat32(i * 4, Endian.little),
      );
      coco = File('test/fixtures/coco80_labels.txt')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expected =
          jsonDecode(File('test/fixtures/bus_expected.json').readAsStringSync())
              as Map<String, dynamic>;
    });

    test('reproduce las detecciones de la referencia en Python', () {
      final layout = YoloOutputLayout.fromShape([1, 84, 2100], coco.length);
      final out = YoloDecoder(labels: coco)
          .decode(output, layout, confidenceThreshold: 0.5);
      final ref = (expected['detections'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(out.length, ref.length);

      final size = (expected['image_size'] as List<dynamic>).cast<int>();
      final lb = LetterboxTransform(
          srcWidth: size[0], srcHeight: size[1], target: 320);
      for (var i = 0; i < ref.length; i++) {
        expect(out[i].label, ref[i]['label']);
        expect(
            out[i].score, closeTo((ref[i]['score'] as num).toDouble(), 1e-5));
        final src = lb.toSource(out[i].box);
        final want = (ref[i]['source_box'] as List<dynamic>).cast<num>();
        expect(src.left, closeTo(want[0].toDouble(), 1e-4));
        expect(src.top, closeTo(want[1].toDouble(), 1e-4));
        expect(src.right, closeTo(want[2].toDouble(), 1e-4));
        expect(src.bottom, closeTo(want[3].toDouble(), 1e-4));
      }
    });

    test('el catálogo descarta clases que no son obstáculos', () {
      final layout = YoloOutputLayout.fromShape([1, 84, 2100], coco.length);
      final out = YoloDecoder(labels: coco).decode(
        output,
        layout,
        confidenceThreshold: 0.5,
        accept: ObstacleCatalog.isObstacle,
      );
      expect(out.map((d) => d.label).toSet(), {'bus', 'person'});
    });
  });
}
