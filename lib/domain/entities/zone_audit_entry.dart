/// Acción registrada sobre una zona de riesgo (control de repudio, STRIDE).
enum AuditAction { created, incremented, edited, deleted }

/// Entrada del registro local de cambios de zonas (HU11, CA4).
class ZoneAuditEntry {
  const ZoneAuditEntry({
    required this.action,
    required this.zoneId,
    required this.zoneType,
    required this.timestamp,
  });

  factory ZoneAuditEntry.fromMap(Map<dynamic, dynamic> map) {
    final actionName = map['action'];
    final zoneId = map['zoneId'];
    final zoneType = map['zoneType'];
    final timestamp = map['timestamp'];
    AuditAction? action;
    for (final value in AuditAction.values) {
      if (value.name == actionName) {
        action = value;
      }
    }
    if (action == null ||
        zoneId is! String ||
        zoneType is! String ||
        timestamp is! int) {
      throw const FormatException('Entrada de auditoría inválida');
    }
    return ZoneAuditEntry(
      action: action,
      zoneId: zoneId,
      zoneType: zoneType,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  final AuditAction action;
  final String zoneId;
  final String zoneType;
  final DateTime timestamp;

  Map<String, Object> toMap() => {
        'action': action.name,
        'zoneId': zoneId,
        'zoneType': zoneType,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is ZoneAuditEntry &&
      other.action == action &&
      other.zoneId == zoneId &&
      other.zoneType == zoneType &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(action, zoneId, zoneType, timestamp);
}
