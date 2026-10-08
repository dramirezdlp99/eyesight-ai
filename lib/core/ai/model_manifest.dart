import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Descripción del modelo empaquetado en `assets/models/model_manifest.json`.
///
/// La genera `ml/scripts/make_manifest.py` cada vez que se exporta un modelo.
class ModelManifest {
  const ModelManifest({
    required this.name,
    required this.file,
    required this.labels,
    required this.sha256,
    required this.inputSize,
    required this.quantization,
    required this.source,
  });

  factory ModelManifest.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final file = json['file'];
    final labels = json['labels'];
    final sha = json['sha256'];
    final input = json['input_size'];
    final quantization = json['quantization'];
    final source = json['source'] ?? '';
    if (name is! String ||
        file is! String ||
        labels is! String ||
        sha is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) ||
        input is! int ||
        input <= 0 ||
        quantization is! String ||
        source is! String) {
      throw const FormatException('model_manifest.json inválido');
    }
    return ModelManifest(
      name: name,
      file: file,
      labels: labels,
      sha256: sha,
      inputSize: input,
      quantization: quantization,
      source: source,
    );
  }

  static ModelManifest parse(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('model_manifest.json inválido');
    }
    return ModelManifest.fromJson(decoded);
  }

  final String name;
  final String file;
  final String labels;
  final String sha256;
  final int inputSize;
  final String quantization;
  final String source;

  static const String assetDirectory = 'assets/models';
  static const String assetPath = '$assetDirectory/model_manifest.json';

  String get modelAsset => '$assetDirectory/$file';
  String get labelsAsset => '$assetDirectory/$labels';
}

/// El modelo no coincide con su resumen SHA-256 (STRIDE: manipulación).
class ModelIntegrityException implements Exception {
  const ModelIntegrityException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() =>
      'ModelIntegrityException: el modelo fue alterado (esperado $expected, obtenido $actual)';
}

/// Verificación de integridad del modelo al iniciar (numeral 4.1.7).
abstract final class ModelIntegrity {
  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  /// Lanza [ModelIntegrityException] si el resumen no coincide.
  static void verify(List<int> modelBytes, ModelManifest manifest) {
    final actual = sha256Hex(modelBytes);
    if (actual != manifest.sha256) {
      throw ModelIntegrityException(manifest.sha256, actual);
    }
  }

  /// Etiquetas del modelo: una por línea, sin líneas vacías.
  static List<String> parseLabels(String text) => text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}
