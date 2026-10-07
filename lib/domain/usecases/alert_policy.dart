import '../../core/ai/obstacle_catalog.dart';
import '../../core/config/app_constants.dart';
import '../entities/detection.dart';
import '../entities/proximity.dart';

/// Patrones de vibración en milisegundos: espera, vibra, espera, vibra…
/// (HU04).
abstract final class HapticPatterns {
  /// Cerca: 3 pulsos cortos.
  static const List<int> near = [0, 120, 90, 120, 90, 120];

  /// Media distancia: 2 pulsos.
  static const List<int> medium = [0, 160, 120, 160];

  /// Lejos: 1 pulso.
  static const List<int> far = [0, 200];

  /// Zona de riesgo: 1 pulso largo, distinguible de los demás (HU04, CA3).
  static const List<int> zone = [0, 700];

  static List<int> forProximity(Proximity proximity) => switch (proximity) {
        Proximity.near => near,
        Proximity.medium => medium,
        Proximity.far => far,
      };
}

/// Alerta decidida para un obstáculo.
class AlertDecision {
  const AlertDecision({
    required this.detection,
    required this.message,
    required this.vibrationPattern,
  });

  final Detection detection;
  final String message;
  final List<int> vibrationPattern;
}

/// Decide qué obstáculo anunciar y cuándo (HU03 y HU04).
///
/// * Solo se anuncian obstáculos en la trayectoria o, fuera de ella, los que
///   están cerca (HU03, CA4).
/// * Primero el más cercano (HU03, CA3).
/// * El mismo obstáculo no se repite antes de 4 s, salvo que pase a «cerca»
///   (HU03, CA2).
class AlertPolicy {
  AlertPolicy({this.repeatAfter = AppConstants.repeatSameObstacleAfter});

  final Duration repeatAfter;
  final Map<String, (DateTime, Proximity)> _last = {};
  AlertDecision? _lastDecision;

  /// Última alerta emitida, para el comando «repetir» (HU09, CA1).
  AlertDecision? get lastDecision => _lastDecision;

  AlertDecision? decide(List<Detection> confirmed, DateTime now) {
    final candidates = confirmed
        .where((d) => d.inPath || d.proximity == Proximity.near)
        .toList()
      ..sort(_byUrgency);
    for (final d in candidates) {
      final previous = _last[d.label];
      final due = previous == null ||
          now.difference(previous.$1) >= repeatAfter ||
          (d.proximity == Proximity.near && previous.$2 != Proximity.near);
      if (due) {
        _last[d.label] = (now, d.proximity);
        final decision = AlertDecision(
          detection: d,
          message: messageFor(d),
          vibrationPattern: HapticPatterns.forProximity(d.proximity),
        );
        _lastDecision = decision;
        return decision;
      }
    }
    return null;
  }

  void reset() {
    _last.clear();
    _lastDecision = null;
  }

  /// Mensaje de voz: «Poste, cerca, al frente» (HU03, CA1).
  static String messageFor(Detection d) {
    final name = ObstacleCatalog.spanishName(d.label);
    return '$name, ${d.proximity.spoken}, ${directionFor(d)}';
  }

  static String directionFor(Detection d) {
    if (d.inPath) {
      return 'al frente';
    }
    return d.centerX < 0.5 ? 'a la izquierda' : 'a la derecha';
  }

  static int _byUrgency(Detection a, Detection b) {
    final p = a.proximity.urgency.compareTo(b.proximity.urgency);
    if (p != 0) {
      return p;
    }
    if (a.inPath != b.inPath) {
      return a.inPath ? -1 : 1;
    }
    final bottom = b.box.bottom.compareTo(a.box.bottom);
    if (bottom != 0) {
      return bottom;
    }
    return b.confidence.compareTo(a.confidence);
  }
}
