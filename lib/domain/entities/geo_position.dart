/// Posición GPS independiente del paquete geolocator, para que el dominio
/// pueda probarse sin el teléfono.
class GeoPosition {
  const GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;

  /// Precisión horizontal estimada en metros (menor es mejor).
  final double accuracyM;
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      other is GeoPosition &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyM == accuracyM &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyM, timestamp);

  @override
  String toString() =>
      'GeoPosition($latitude, $longitude, ±${accuracyM.toStringAsFixed(1)} m)';
}
