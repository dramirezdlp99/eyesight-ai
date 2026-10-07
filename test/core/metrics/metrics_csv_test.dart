import 'package:eyesight_ai/core/metrics/metrics_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 14);

  MetricSample sample(double inference, {double? alert, double fps = 8}) =>
      MetricSample(
        timestamp: t0,
        testCase: 'CP-02',
        fps: fps,
        inferenceMs: inference,
        captureToAlertMs: alert,
        detectedLabel: 'pole',
        confidence: 0.82,
        groundTruth: 'pole',
        lat: 1.2136,
        lng: -77.2811,
      );

  group('MetricsSummary (numeral 4.4.3)', () {
    test('promedio, percentil 95 y cumplimiento de metas', () {
      final data = [
        for (var i = 1; i <= 20; i++) sample(i * 10.0, alert: i * 50.0),
      ];
      final s = MetricsSummary.of(data);
      expect(s.samples, 20);
      expect(s.meanInferenceMs, closeTo(105, 1e-9));
      expect(s.p95InferenceMs, 190);
      expect(s.inferenceGoalRate, closeTo(9 / 20, 1e-9)); // 10..90 < 100 ms
      expect(s.alertGoalRate, closeTo(10 / 20, 1e-9)); // 50..500 <= 500 ms
      expect(s.meanFps, 8);
    });

    test('sin muestras devuelve ceros', () {
      final s = MetricsSummary.of(const []);
      expect(s.samples, 0);
      expect(s.meanCaptureToAlertMs, isNull);
    });

    test('percentil de lista vacía y de un elemento', () {
      expect(MetricsSummary.percentile(const [], 95), 0);
      expect(MetricsSummary.percentile(const [42], 95), 42);
    });
  });

  group('MetricsCsv (HU15)', () {
    test('sin coordenadas por defecto (CA3)', () {
      final csv = MetricsCsv.build([sample(86)]);
      final lines = csv.trim().split('\r\n');
      expect(lines.first, MetricsCsv.header.join(','));
      expect(lines[1],
          '2026-10-07T14:00:00.000Z,CP-02,8.00,86.00,,pole,0.8200,pole');
      expect(csv.contains('1.213600'), isFalse);
    });

    test('con coordenadas solo si se activan', () {
      final csv = MetricsCsv.build([sample(86)], includeCoordinates: true);
      expect(csv.split('\r\n').first.endsWith('latitud,longitud'), isTrue);
      expect(csv.contains('1.213600,-77.281100'), isTrue);
    });

    test('escapa comas, comillas y neutraliza fórmulas', () {
      expect(MetricsCsv.escape('a,b'), '"a,b"');
      expect(MetricsCsv.escape('di "hola"'), '"di ""hola"""');
      expect(MetricsCsv.escape('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
      expect(MetricsCsv.escape('-77.28'), '-77.28');
      expect(MetricsCsv.escape('@SUM'), "'@SUM");
    });
  });
}
