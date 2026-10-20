import 'metrics_csv.dart';

/// Registro de métricas del modo de pruebas (diagrama de clases:
/// MetricsLogger con `log` y `exportCsv`; HU15, RF21).
///
/// Las muestras viven solo en memoria mientras dura la prueba; nada se
/// guarda ni se envía hasta que el investigador exporta el CSV.
class MetricsLogger {
  MetricsLogger({this.capacity = 50000});

  /// Máximo de muestras guardadas; al llegar al límite se descartan las más
  /// antiguas para no agotar la memoria en pruebas largas.
  final int capacity;

  final List<MetricSample> _samples = [];

  List<MetricSample> get samples => List.unmodifiable(_samples);

  int get length => _samples.length;

  bool get isEmpty => _samples.isEmpty;

  void log(MetricSample sample) {
    if (_samples.length >= capacity) {
      _samples.removeAt(0);
    }
    _samples.add(sample);
  }

  /// Muestras de los últimos [window] antes de [now] (gráfica en vivo).
  List<MetricSample> recent(DateTime now, Duration window) {
    final from = now.subtract(window);
    return [
      for (final s in _samples)
        if (!s.timestamp.isBefore(from)) s,
    ];
  }

  MetricsSummary summary() => MetricsSummary.of(_samples);

  /// CSV sin coordenadas, salvo que se pidan de forma explícita (HU15, CA3).
  String exportCsv({bool includeCoordinates = false}) =>
      MetricsCsv.build(_samples, includeCoordinates: includeCoordinates);

  void clear() => _samples.clear();
}
