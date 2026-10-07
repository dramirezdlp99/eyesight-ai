import '../../core/config/app_constants.dart';
import '../entities/detection.dart';

/// Confirma una detección solo si aparece en varios cuadros consecutivos,
/// para evitar falsas alarmas (HU03, CA1; diagrama de clases).
class StabilityFilter {
  StabilityFilter({this.window = AppConstants.stabilityWindow})
      : assert(window >= 1);

  /// Cuadros consecutivos necesarios.
  final int window;

  final Map<String, int> _streak = {};
  final Set<String> _confirmed = {};

  /// Procesa las detecciones de un cuadro y devuelve las confirmadas, una por
  /// clase: la más urgente (más cercana y luego de mayor confianza).
  List<Detection> update(List<Detection> frame) {
    final best = <String, Detection>{};
    for (final d in frame) {
      final current = best[d.label];
      if (current == null || _moreUrgent(d, current)) {
        best[d.label] = d;
      }
    }
    _streak.removeWhere((label, _) => !best.containsKey(label));
    for (final label in best.keys) {
      _streak[label] = (_streak[label] ?? 0) + 1;
    }
    _confirmed
      ..clear()
      ..addAll(
          _streak.entries.where((e) => e.value >= window).map((e) => e.key));
    return [
      for (final entry in best.entries)
        if (_confirmed.contains(entry.key)) entry.value,
    ];
  }

  /// `true` si la clase de [detection] está confirmada en el cuadro actual.
  bool accept(Detection detection) => _confirmed.contains(detection.label);

  void reset() {
    _streak.clear();
    _confirmed.clear();
  }

  static bool _moreUrgent(Detection a, Detection b) {
    if (a.proximity != b.proximity) {
      return a.proximity.isCloserThan(b.proximity);
    }
    if (a.inPath != b.inPath) {
      return a.inPath;
    }
    return a.confidence > b.confidence;
  }
}
