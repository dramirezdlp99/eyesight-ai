import 'zone_origin.dart';

/// Zona de riesgo georreferenciada (RF10, RF11 y diagrama de clases).
class RiskZone {
  const RiskZone({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.origin,
    required this.createdAt,
    required this.lastSeenAt,
    this.count = 1,
    this.note = '',
  });

  /// Reconstruye una zona desde Hive. Lanza [FormatException] si el registro
  /// está incompleto o fuera de rango (RNF12).
  factory RiskZone.fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'];
    final type = map['type'];
    final lat = map['lat'];
    final lng = map['lng'];
    final radius = map['radiusM'];
    final originRaw = map['origin'];
    final origin = ZoneOrigin.fromName(originRaw is String ? originRaw : null);
    final created = map['createdAt'];
    final lastSeen = map['lastSeenAt'] ?? created;
    final count = map['count'] ?? 1;
    final note = map['note'] ?? '';
    if (id is! String ||
        id.isEmpty ||
        type is! String ||
        type.isEmpty ||
        lat is! num ||
        lng is! num ||
        radius is! num ||
        origin == null ||
        created is! int ||
        lastSeen is! int ||
        count is! int ||
        note is! String) {
      throw const FormatException('Registro de zona de riesgo inválido');
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180 || count < 1) {
      throw const FormatException('Zona de riesgo fuera de rango');
    }
    return RiskZone(
      id: id,
      type: type,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      radiusM: radius.toDouble(),
      origin: origin,
      createdAt: DateTime.fromMillisecondsSinceEpoch(created),
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(lastSeen),
      count: count,
      note: note,
    );
  }

  final String id;

  /// Clave del tipo de riesgo (por ejemplo `pothole`), ver ObstacleCatalog.
  final String type;
  final double lat;
  final double lng;
  final double radiusM;
  final ZoneOrigin origin;

  /// Número de encuentros registrados en la zona (HU06, CA2).
  final int count;
  final String note;
  final DateTime createdAt;

  /// Último encuentro: evita contar varias veces el mismo paso.
  final DateTime lastSeenAt;

  RiskZone copyWith({
    String? type,
    double? radiusM,
    int? count,
    String? note,
    DateTime? lastSeenAt,
  }) =>
      RiskZone(
        id: id,
        type: type ?? this.type,
        lat: lat,
        lng: lng,
        radiusM: radiusM ?? this.radiusM,
        origin: origin,
        createdAt: createdAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        count: count ?? this.count,
        note: note ?? this.note,
      );

  Map<String, Object> toMap() => {
        'id': id,
        'type': type,
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
        'origin': origin.name,
        'count': count,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastSeenAt': lastSeenAt.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is RiskZone &&
      other.id == id &&
      other.type == type &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusM == radiusM &&
      other.origin == origin &&
      other.count == count &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.lastSeenAt == lastSeenAt;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        lat,
        lng,
        radiusM,
        origin,
        count,
        note,
        createdAt,
        lastSeenAt,
      );

  @override
  String toString() => 'RiskZone($id, $type, ${origin.name}, x$count)';
}
