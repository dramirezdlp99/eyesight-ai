import 'dart:io';

import 'package:eyesight_ai/core/ai/model_manifest.dart';
import 'package:eyesight_ai/core/ai/yolo_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelManifest', () {
    test('rechaza manifiestos incompletos o con resumen inválido', () {
      expect(() => ModelManifest.parse('[]'), throwsFormatException);
      expect(() => ModelManifest.parse('{"name": "x"}'), throwsFormatException);
      expect(
        () => ModelManifest.parse(
          '{"name":"x","file":"m.tflite","labels":"l.txt","sha256":"abc",'
          '"input_size":320,"quantization":"int8"}',
        ),
        throwsFormatException,
      );
    });

    test('rutas de los recursos dentro de assets/models', () {
      final m = ModelManifest.parse(
        '{"name":"x","file":"m.tflite","labels":"l.txt",'
        '"sha256":"${'a' * 64}","input_size":320,"quantization":"int8"}',
      );
      expect(m.modelAsset, 'assets/models/m.tflite');
      expect(m.labelsAsset, 'assets/models/l.txt');
      expect(m.source, '');
    });
  });

  group('ModelIntegrity (STRIDE: manipulación)', () {
    test('acepta bytes con el resumen correcto y rechaza alterados', () {
      final bytes = [1, 2, 3, 4];
      final sha = ModelIntegrity.sha256Hex(bytes);
      final m = ModelManifest(
        name: 'x',
        file: 'm',
        labels: 'l',
        sha256: sha,
        inputSize: 320,
        quantization: 'float32',
        source: '',
      );
      ModelIntegrity.verify(bytes, m);
      expect(
        () => ModelIntegrity.verify([1, 2, 3, 5], m),
        throwsA(isA<ModelIntegrityException>()),
      );
    });

    test('parseLabels ignora líneas vacías y finales de línea de Windows', () {
      expect(ModelIntegrity.parseLabels('person\r\n\r\npole\n'),
          ['person', 'pole']);
    });
  });

  group('modelo empaquetado en assets/models', () {
    late ModelManifest manifest;
    setUpAll(() {
      manifest = ModelManifest.parse(
        File('assets/models/model_manifest.json').readAsStringSync(),
      );
    });

    test('el archivo del modelo coincide con su resumen SHA-256', () {
      final bytes = File(manifest.modelAsset).readAsBytesSync();
      ModelIntegrity.verify(bytes, manifest);
    });

    test('las etiquetas corresponden a la salida del modelo', () {
      final labels = ModelIntegrity.parseLabels(
        File(manifest.labelsAsset).readAsStringSync(),
      );
      expect(manifest.inputSize, 320);
      // YOLOv8n de 320 px: [1, 4 + clases, 2100].
      final layout = YoloOutputLayout.fromShape(
          [1, 4 + labels.length, 2100], labels.length);
      expect(layout.numCandidates, 2100);
      expect(labels.first, 'person');
    });
  });
}
