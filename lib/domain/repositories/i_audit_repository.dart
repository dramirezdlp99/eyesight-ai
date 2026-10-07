import '../entities/zone_audit_entry.dart';

/// Puerto del registro local de cambios de zonas (HU11, CA4).
abstract interface class IAuditRepository {
  Future<void> add(ZoneAuditEntry entry);

  Future<List<ZoneAuditEntry>> all();

  Future<void> clear();
}
