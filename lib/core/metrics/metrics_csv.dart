import 'dart:math' as math;

import '../config/app_constants.dart';

/// Muestra del modo de pruebas (HU15, RF21).
class MetricSample {
  const MetricSample({
    required this.timestamp,
    required this.testCase,
    required this.fps,
    required this.inferenceMs,
    this.captureToAlertMs,
    this.detectedLabel,
    this.confidence,
    this.groundTruth,
    this.lat,
    this.lng,
  });

  final DateTime timestamp;
  final String testCase;
  final double fps;
  final double inferenceMs;

  /// Tiempo desde la captura del cuadro hasta el inicio de la alerta (RNF02).
  final double? captureToAlertMs;
  final String? detectedLabel;
  final double? confidence;

  /// Etiqueta real elegida por el investigador (HU15, CA2).
  final String? groundTruth;
  final double? lat;
  final double? lng;
}

/// Resumen estadístico para las tablas del numeral 4.4.3.
class MetricsSummary {
  const MetricsSummary({
    required this.samples,
    required this.meanInferenceMs,
    required this.p95InferenceMs,
    required this.meanFps,
    required this.meanCaptureToAlertMs,
    required this.inferenceGoalRate,
    required this.alertGoalRate,
  });

  factory MetricsSummary.of(List<MetricSample> data) {
    if (data.isEmpty) {
      return const MetricsSummary(
        samples: 0,
        meanInferenceMs: 0,
        p95InferenceMs: 0,
        meanFps: 0,
        meanCaptureToAlertMs: null,
        inferenceGoalRate: 0,
        alertGoalRate: null,
      );
    }
    final inference = data.map((s) => s.inferenceMs).toList()..sort();
    final alerts = [
      for (final s in data)
        if (s.captureToAlertMs != null) s.captureToAlertMs!,
    ];
    final withinInference =
        inference.where((v) => v < AppConstants.inferenceLatencyGoalMs).length;
    final withinAlert =
        alerts.where((v) => v <= AppConstants.captureToAlertGoalMs).length;
    return MetricsSummary(
      samples: data.length,
      meanInferenceMs: _mean(inference),
      p95InferenceMs: percentile(inference, 95),
      meanFps: _mean(data.map((s) => s.fps).toList()),
      meanCaptureToAlertMs: alerts.isEmpty ? null : _mean(alerts),
      inferenceGoalRate: withinInference / inference.length,
      alertGoalRate: alerts.isEmpty ? null : withinAlert / alerts.length,
    );
  }

  final int samples;
  final double meanInferenceMs;
  final double p95InferenceMs;
  final double meanFps;
  final double? meanCaptureToAlertMs;

  /// Proporción de cuadros con inferencia menor a 100 ms (RNF01).
  final double inferenceGoalRate;

  /// Proporción de alertas en 500 ms o menos (RNF02).
  final double? alertGoalRate;

  static double _mean(List<double> v) =>
      v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

  /// Percentil por el método del rango más cercano; [sorted] debe venir
  /// ordenado de menor a mayor.
  static double percentile(List<double> sorted, int p) {
    if (sorted.isEmpty) {
      return 0.0;
    }
    final rank = (p / 100 * sorted.length).ceil();
    final index = math.max(0, math.min(sorted.length - 1, rank - 1));
    return sorted[index];
  }
}

/// Construye el CSV del modo de pruebas (HU15, CA3).
abstract final class MetricsCsv {
  static const List<String> header = [
    'timestamp_iso',
    'caso',
    'fps',
    'inferencia_ms',
    'captura_a_alerta_ms',
    'clase_detectada',
    'confianza',
    'etiqueta_real',
  ];

  /// Por privacidad, las coordenadas solo se incluyen si el investigador las
  /// activa de forma explícita.
  static String build(List<MetricSample> samples,
      {bool includeCoordinates = false}) {
    final rows = <List<String>>[
      [
        ...header,
        if (includeCoordinates) ...['latitud', 'longitud']
      ],
      for (final s in samples)
        [
          s.timestamp.toUtc().toIso8601String(),
          s.testCase,
          s.fps.toStringAsFixed(2),
          s.inferenceMs.toStringAsFixed(2),
          s.captureToAlertMs?.toStringAsFixed(2) ?? '',
          s.detectedLabel ?? '',
          s.confidence?.toStringAsFixed(4) ?? '',
          s.groundTruth ?? '',
          if (includeCoordinates) ...[
            s.lat?.toStringAsFixed(6) ?? '',
            s.lng?.toStringAsFixed(6) ?? '',
          ],
        ],
    ];
    return '${rows.map((r) => r.map(escape).join(',')).join('\r\n')}\r\n';
  }

  /// Escapa comillas, comas y saltos de línea, y neutraliza fórmulas de hoja
  /// de cálculo (inyección CSV) anteponiendo un apóstrofo.
  static String escape(String value) {
    var v = value;
    if (v.isNotEmpty &&
        '=+-@\t\r'.contains(v[0]) &&
        double.tryParse(v) == null) {
      v = "'$v";
    }
    if (v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r')) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
