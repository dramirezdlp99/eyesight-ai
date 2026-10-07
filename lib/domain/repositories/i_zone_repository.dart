import '../entities/risk_zone.dart';

/// Puerto de la memoria georreferenciada (diagrama de clases, patrón
/// Repository). La implementación cifrada en Hive vive en `lib/data`.
abstract interface class IZoneRepository {
  Future<void> save(RiskZone zone);

  Future<List<RiskZone>> all();

  Future<RiskZone?> byId(String id);

  Future<void> update(RiskZone zone);

  Future<void> delete(String id);

  Future<int> count();

  Future<void> clear();
}
