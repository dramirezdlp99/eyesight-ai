import 'package:eyesight_ai/core/metrics/metrics_csv.dart';
import 'package:eyesight_ai/core/metrics/metrics_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 14);

  MetricSample at(int second, {double inference = 50}) => MetricSample(
        timestamp: t0.add(Duration(seconds: second)),
        testCase: 'CP-02',
        fps: 8,
        inferenceMs: inference,
        detectedLabel: 'pole',
        confidence: 0.8,
        groundTruth: 'pole',
        lat: 1.2136,
        lng: -77.2811,
      );

  test('registra muestras y calcula el resumen', () {
    final logger = MetricsLogger()
      ..log(at(0, inference: 40))
      ..log(at(1, inference: 120));
    expect(logger.length, 2);
    expect(logger.summary().meanInferenceMs, 80);
    expect(logger.summary().inferenceGoalRate, 0.5);
  });

  test('conserva solo las más recientes al llegar al límite', () {
    final logger = MetricsLogger(capacity: 3);
    for (var i = 0; i < 5; i++) {
      logger.log(at(i));
    }
    expect(logger.length, 3);
    expect(logger.samples.first.timestamp, t0.add(const Duration(seconds: 2)));
  });

  test('ventana reciente para la gráfica', () {
    final logger = MetricsLogger();
    for (var i = 0; i < 60; i++) {
      logger.log(at(i));
    }
    final recent = logger.recent(
      t0.add(const Duration(seconds: 59)),
      const Duration(seconds: 30),
    );
    expect(recent, hasLength(31));
  });

  test('CA3 (HU15): el CSV no lleva coordenadas salvo que se pidan', () {
    final logger = MetricsLogger()..log(at(0));
    expect(logger.exportCsv(), isNot(contains('latitud')));
    expect(logger.exportCsv(), isNot(contains('1.213600')));
    final withGps = logger.exportCsv(includeCoordinates: true);
    expect(withGps, contains('latitud'));
    expect(withGps, contains('1.213600'));
    logger.clear();
    expect(logger.isEmpty, isTrue);
  });
}
