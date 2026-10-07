import 'proximity.dart';

/// Registro del historial de detecciones (RF17 y diagrama de clases).
///
/// [lat] y [lng] son `null` cuando no había una posición GPS válida
/// (HU06, CA4).
class DetectionRecord {
  const DetectionRecord({
    required this.label,
    required this.confidence,
    required this.proximity,
    required this.timestamp,
    this.lat,
    this.lng,
  });

  factory DetectionRecord.fromMap(Map<dynamic, dynamic> map) {
    final label = map['label'];
    final confidence = map['confidence'];
    final proximityRaw = map['proximity'];
    final proximity =
        Proximity.fromName(proximityRaw is String ? proximityRaw : null);
    final timestamp = map['timestamp'];
    final lat = map['lat'];
    final lng = map['lng'];
    if (label is! String ||
        label.isEmpty ||
        confidence is! num ||
        proximity == null ||
        timestamp is! int ||
        (lat != null && lat is! num) ||
        (lng != null && lng is! num)) {
      throw const FormatException('Registro de historial inválido');
    }
    return DetectionRecord(
      label: label,
      confidence: confidence.toDouble(),
      proximity: proximity,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      lat: (lat as num?)?.toDouble(),
      lng: (lng as num?)?.toDouble(),
    );
  }

  final String label;
  final double confidence;
  final Proximity proximity;
  final double? lat;
  final double? lng;
  final DateTime timestamp;

  bool get hasPosition => lat != null && lng != null;

  Map<String, Object?> toMap() => {
        'label': label,
        'confidence': confidence,
        'proximity': proximity.name,
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is DetectionRecord &&
      other.label == label &&
      other.confidence == confidence &&
      other.proximity == proximity &&
      other.lat == lat &&
      other.lng == lng &&
      other.timestamp == timestamp;

  @override
  int get hashCode =>
      Object.hash(label, confidence, proximity, lat, lng, timestamp);
}
