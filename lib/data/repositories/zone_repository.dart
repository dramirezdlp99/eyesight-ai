import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/risk_zone.dart';
import '../../domain/repositories/i_zone_repository.dart';

/// Memoria georreferenciada en Hive cifrado (RF10, RF11, RF15, RF16).
///
/// Los registros dañados se omiten en lugar de detener la aplicación
/// (RNF05, tolerancia a fallos).
class ZoneRepository implements IZoneRepository {
  ZoneRepository(this._box);

  final Box<dynamic> _box;

  @override
  Future<void> save(RiskZone zone) => _box.put(zone.id, zone.toMap());

  @override
  Future<List<RiskZone>> all() async {
    final zones = <RiskZone>[];
    for (final raw in _box.values) {
      final zone = _decode(raw);
      if (zone != null) {
        zones.add(zone);
      }
    }
    zones.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return zones;
  }

  @override
  Future<RiskZone?> byId(String id) async => _decode(_box.get(id));

  @override
  Future<void> update(RiskZone zone) async {
    if (!_box.containsKey(zone.id)) {
      throw StateError('La zona ${zone.id} no existe');
    }
    await _box.put(zone.id, zone.toMap());
  }

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<int> count() async => _box.length;

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  static RiskZone? _decode(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      return RiskZone.fromMap(raw);
    } on FormatException {
      return null;
    }
  }
}
