import 'dart:math' as math;

/// Cálculos geográficos del dominio.
abstract final class GeoMath {
  /// Radio ecuatorial de la Tierra en metros (el mismo que usa geolocator).
  static const double earthRadiusM = 6378137.0;

  /// Distancia en metros entre dos coordenadas con la fórmula de haversine,
  /// equivalente a `Geolocator.distanceBetween` «c:Geo».
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
