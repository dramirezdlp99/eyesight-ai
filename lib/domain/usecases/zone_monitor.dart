import '../../core/ai/obstacle_catalog.dart';
import '../../core/config/app_constants.dart';
import '../entities/geo_position.dart';
import '../entities/risk_zone.dart';
import 'geo_math.dart';

/// Aviso preventivo de una zona registrada (HU08).
class ZoneWarning {
  const ZoneWarning({required this.zone, required this.distanceM});

  final RiskZone zone;
  final double distanceM;

  /// «Atención: escalón a 18 metros» (HU08, CA1).
  String get message {
    final name = ObstacleCatalog.spanishName(zone.type).toLowerCase();
    final meters = distanceM.round();
    final unit = meters == 1 ? 'metro' : 'metros';
    return 'Atención: $name a $meters $unit';
  }
}

/// Vigila la cercanía a las zonas de riesgo registradas (HU08, RF12).
///
/// Una zona anunciada no se repite hasta que el usuario sale de su radio más
/// 10 m, o hasta que pasan 60 s (HU08, CA2). Con una precisión GPS peor que
/// 30 m no se emiten avisos (HU08, CA4).
class ZoneMonitor {
  ZoneMonitor({
    this.rearmExtraM = AppConstants.zoneRearmExtraM,
    this.repeatAfter = AppConstants.zoneRepeatAfter,
    this.maxAccuracyM = AppConstants.maxAccuracyToWarnM,
  });

  final double rearmExtraM;
  final Duration repeatAfter;
  final double maxAccuracyM;
  final Map<String, DateTime> _announced = {};

  ZoneWarning? check(GeoPosition position, List<RiskZone> zones, DateTime now) {
    if (position.accuracyM > maxAccuracyM) {
      return null;
    }
    final inside = <ZoneWarning>[];
    final ids = <String>{};
    for (final z in zones) {
      ids.add(z.id);
      final d = GeoMath.distanceMeters(
        position.latitude,
        position.longitude,
        z.lat,
        z.lng,
      );
      if (d > z.radiusM + rearmExtraM) {
        _announced.remove(z.id);
      } else if (d <= z.radiusM) {
        inside.add(ZoneWarning(zone: z, distanceM: d));
      }
    }
    // Zonas eliminadas por el acompañante dejan de vigilarse.
    _announced.removeWhere((id, _) => !ids.contains(id));

    inside.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    for (final w in inside) {
      final last = _announced[w.zone.id];
      if (last == null || now.difference(last) >= repeatAfter) {
        _announced[w.zone.id] = now;
        return w;
      }
    }
    return null;
  }

  void reset() => _announced.clear();
}
