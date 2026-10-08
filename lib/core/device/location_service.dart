import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_position.dart';

/// Posición GPS del teléfono (RF10, RF12).
abstract interface class ILocationService {
  /// Pide el permiso si hace falta; `false` si fue negado o el GPS está
  /// apagado.
  Future<bool> ensureReady();

  /// Posición actual o `null` si no hay señal (HU06 CA4, RNF05).
  Future<GeoPosition?> current();
}

class GeolocatorLocationService implements ILocationService {
  @override
  Future<bool> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Future<GeoPosition?> current() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return GeoPosition(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyM: p.accuracy,
        timestamp: DateTime.now(),
      );
    } on Object {
      return null;
    }
  }
}
