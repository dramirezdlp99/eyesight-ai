import 'dart:math';

import '../../core/ai/obstacle_catalog.dart';
import '../../core/security/input_validators.dart';
import '../entities/app_settings.dart';
import '../entities/detection.dart';
import '../entities/geo_position.dart';
import '../entities/risk_zone.dart';
import '../entities/zone_audit_entry.dart';
import '../repositories/i_audit_repository.dart';
import '../repositories/i_zone_repository.dart';
import 'zone_registration_policy.dart';

/// Aplica las reglas de zonas sobre el repositorio y deja constancia de cada
/// cambio en el registro de auditoría (HU06, HU07, HU11).
class ZoneService {
  ZoneService({
    required IZoneRepository zones,
    required IAuditRepository audit,
    DateTime Function()? clock,
    String Function()? newId,
    this.policy = const ZoneRegistrationPolicy(),
  })  : _zones = zones,
        _audit = audit,
        _clock = clock ?? DateTime.now,
        _newId = newId ?? randomId;

  final IZoneRepository _zones;
  final IAuditRepository _audit;
  final DateTime Function() _clock;
  final String Function() _newId;
  final ZoneRegistrationPolicy policy;

  /// Registro automático a partir de una detección confirmada (HU06).
  Future<ZoneRegistration> registerDetection(
    Detection detection,
    GeoPosition? position,
    AppSettings settings,
  ) async {
    final result = policy.evaluateDetection(
      detection: detection,
      position: position,
      zones: await _zones.all(),
      radiusM: settings.alertRadiusM,
      now: _clock(),
      newId: _newId,
      enabled: settings.autoZones,
    );
    await _apply(result);
    return result;
  }

  /// Registro manual por voz o gesto (HU07).
  Future<ZoneRegistration> registerManual(
    String type,
    GeoPosition? position,
    AppSettings settings,
  ) async {
    final result = policy.evaluateManual(
      type: type,
      position: position,
      zones: await _zones.all(),
      radiusM: settings.alertRadiusM,
      now: _clock(),
      newId: _newId,
    );
    await _apply(result);
    return result;
  }

  /// Edita tipo, radio o nota (HU11). Devuelve `null` si se guardó, o el
  /// mensaje de error para mostrar al acompañante.
  Future<String?> edit(
    String id, {
    String? type,
    double? radiusM,
    String? note,
  }) async {
    final current = await _zones.byId(id);
    if (current == null) {
      return 'La zona ya no existe.';
    }
    if (type != null && !ObstacleCatalog.createsZone(type)) {
      return 'Tipo de riesgo no válido.';
    }
    if (radiusM != null) {
      final error = InputValidators.radius(radiusM);
      if (error != null) {
        return error;
      }
    }
    String? cleanNote;
    if (note != null) {
      final error = InputValidators.note(note);
      if (error != null) {
        return error;
      }
      cleanNote = InputValidators.sanitizeNote(note);
    }
    final updated = current.copyWith(
      type: type == null ? null : ObstacleCatalog.normalize(type),
      radiusM: radiusM,
      note: cleanNote,
    );
    await _zones.update(updated);
    await _log(AuditAction.edited, updated);
    return null;
  }

  /// Elimina una zona; deja de generar alertas (HU11, CA3).
  Future<bool> delete(String id) async {
    final current = await _zones.byId(id);
    if (current == null) {
      return false;
    }
    await _zones.delete(id);
    await _log(AuditAction.deleted, current);
    return true;
  }

  Future<void> _apply(ZoneRegistration result) async {
    switch (result) {
      case ZoneCreated(:final zone):
        await _zones.save(zone);
        await _log(AuditAction.created, zone);
      case ZoneIncremented(:final zone):
        await _zones.update(zone);
        await _log(AuditAction.incremented, zone);
      case ZoneSkipped():
        break;
    }
  }

  Future<void> _log(AuditAction action, RiskZone zone) => _audit.add(
        ZoneAuditEntry(
          action: action,
          zoneId: zone.id,
          zoneType: zone.type,
          timestamp: _clock(),
        ),
      );

  /// Identificador aleatorio de 128 bits en hexadecimal.
  static String randomId() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
