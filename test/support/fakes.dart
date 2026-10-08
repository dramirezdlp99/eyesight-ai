import 'package:eyesight_ai/core/security/secure_store.dart';
import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/detection_record.dart';
import 'package:eyesight_ai/domain/entities/risk_zone.dart';
import 'package:eyesight_ai/domain/entities/zone_audit_entry.dart';
import 'package:eyesight_ai/domain/repositories/i_audit_repository.dart';
import 'package:eyesight_ai/domain/repositories/i_history_repository.dart';
import 'package:eyesight_ai/domain/repositories/i_settings_repository.dart';
import 'package:eyesight_ai/domain/repositories/i_zone_repository.dart';

/// Almacén seguro en memoria, en lugar del Android Keystore.
class InMemorySecureStore implements ISecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class InMemoryZoneRepository implements IZoneRepository {
  final Map<String, RiskZone> zones = {};

  @override
  Future<List<RiskZone>> all() async => zones.values.toList();

  @override
  Future<RiskZone?> byId(String id) async => zones[id];

  @override
  Future<void> clear() async => zones.clear();

  @override
  Future<int> count() async => zones.length;

  @override
  Future<void> delete(String id) async => zones.remove(id);

  @override
  Future<void> save(RiskZone zone) async => zones[zone.id] = zone;

  @override
  Future<void> update(RiskZone zone) async {
    if (!zones.containsKey(zone.id)) {
      throw StateError('no existe');
    }
    zones[zone.id] = zone;
  }
}

class InMemoryAuditRepository implements IAuditRepository {
  final List<ZoneAuditEntry> entries = [];

  @override
  Future<void> add(ZoneAuditEntry entry) async => entries.add(entry);

  @override
  Future<List<ZoneAuditEntry>> all() async => entries.reversed.toList();

  @override
  Future<void> clear() async => entries.clear();
}

class InMemoryHistoryRepository implements IHistoryRepository {
  final List<DetectionRecord> records = [];
  DateTime? lastCutoff;

  @override
  Future<void> add(DetectionRecord record) async => records.add(record);

  @override
  Future<void> clear() async => records.clear();

  @override
  Future<int> count() async => records.length;

  @override
  Future<int> purgeOlderThan(DateTime cutoff) async {
    lastCutoff = cutoff;
    final before = records.length;
    records.removeWhere((r) => r.timestamp.isBefore(cutoff));
    return before - records.length;
  }

  @override
  Future<List<DetectionRecord>> query({
    DateTime? from,
    DateTime? to,
    String? label,
  }) async =>
      records.toList();
}

class InMemorySettingsRepository implements ISettingsRepository {
  InMemorySettingsRepository([this.value = const AppSettings()]);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;

  @override
  Future<void> clear() async => value = const AppSettings();
}
