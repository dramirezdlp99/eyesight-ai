import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/zone_audit_entry.dart';
import '../../domain/repositories/i_audit_repository.dart';

/// Registro local de cambios de zonas (control de repudio, HU11 CA4).
class AuditRepository implements IAuditRepository {
  AuditRepository(this._box);

  final Box<dynamic> _box;

  @override
  Future<void> add(ZoneAuditEntry entry) async {
    await _box.add(entry.toMap());
  }

  @override
  Future<List<ZoneAuditEntry>> all() async {
    final entries = <ZoneAuditEntry>[];
    for (final raw in _box.values) {
      if (raw is! Map) {
        continue;
      }
      try {
        entries.add(ZoneAuditEntry.fromMap(raw));
      } on FormatException {
        continue;
      }
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }
}
