import '../../core/ai/obstacle_catalog.dart';
import '../../core/config/app_constants.dart';
import '../entities/detection.dart';
import '../entities/geo_position.dart';
import '../entities/proximity.dart';
import '../entities/risk_zone.dart';
import '../entities/zone_origin.dart';
import 'geo_math.dart';

/// Motivo por el que una detección no genera una zona.
enum ZoneSkipReason {
  /// Obstáculo móvil o fijo de bajo riesgo (HU06, CA3).
  notFixedHazard,

  /// El obstáculo no está «cerca» (HU06, CA1).
  notNear,

  /// No hay posición GPS: solo se guarda en el historial (HU06, CA4).
  noPosition,

  /// La precisión del GPS es peor que 20 m (HU06, CA1).
  lowAccuracy,

  /// La zona ya contó este encuentro hace menos de 60 s.
  alreadyCounted,

  /// El registro automático está desactivado en los ajustes.
  disabled,
}

/// Resultado de evaluar una detección para la memoria georreferenciada.
sealed class ZoneRegistration {
  const ZoneRegistration();
}

final class ZoneCreated extends ZoneRegistration {
  const ZoneCreated(this.zone);
  final RiskZone zone;
}

final class ZoneIncremented extends ZoneRegistration {
  const ZoneIncremented(this.zone);
  final RiskZone zone;
}

final class ZoneSkipped extends ZoneRegistration {
  const ZoneSkipped(this.reason);
  final ZoneSkipReason reason;
}

/// Reglas del registro automático y manual de zonas (HU06 y HU07).
class ZoneRegistrationPolicy {
  const ZoneRegistrationPolicy({
    this.mergeDistanceM = AppConstants.zoneMergeDistanceM,
    this.maxAccuracyM = AppConstants.maxAccuracyToRegisterM,
    this.recountAfter = AppConstants.zoneRepeatAfter,
  });

  final double mergeDistanceM;
  final double maxAccuracyM;
  final Duration recountAfter;

  /// Registro automático a partir de una detección confirmada (HU06).
  ZoneRegistration evaluateDetection({
    required Detection detection,
    required GeoPosition? position,
    required List<RiskZone> zones,
    required double radiusM,
    required DateTime now,
    required String Function() newId,
    bool enabled = true,
  }) {
    if (!enabled) {
      return const ZoneSkipped(ZoneSkipReason.disabled);
    }
    if (!ObstacleCatalog.createsZone(detection.label)) {
      return const ZoneSkipped(ZoneSkipReason.notFixedHazard);
    }
    if (detection.proximity != Proximity.near) {
      return const ZoneSkipped(ZoneSkipReason.notNear);
    }
    return _register(
      type: ObstacleCatalog.normalize(detection.label),
      origin: ZoneOrigin.automatic,
      position: position,
      zones: zones,
      radiusM: radiusM,
      now: now,
      newId: newId,
    );
  }

  /// Registro manual por voz o gesto (HU07). Si ya existe una zona del mismo
  /// tipo a menos de 10 m, se cuenta como un nuevo encuentro.
  ZoneRegistration evaluateManual({
    required String type,
    required GeoPosition? position,
    required List<RiskZone> zones,
    required double radiusM,
    required DateTime now,
    required String Function() newId,
  }) =>
      _register(
        type: ObstacleCatalog.normalize(type),
        origin: ZoneOrigin.manual,
        position: position,
        zones: zones,
        radiusM: radiusM,
        now: now,
        newId: newId,
        ignoreRecountWindow: true,
      );

  ZoneRegistration _register({
    required String type,
    required ZoneOrigin origin,
    required GeoPosition? position,
    required List<RiskZone> zones,
    required double radiusM,
    required DateTime now,
    required String Function() newId,
    bool ignoreRecountWindow = false,
  }) {
    if (position == null) {
      return const ZoneSkipped(ZoneSkipReason.noPosition);
    }
    if (position.accuracyM > maxAccuracyM) {
      return const ZoneSkipped(ZoneSkipReason.lowAccuracy);
    }
    RiskZone? nearest;
    var nearestDistance = double.infinity;
    for (final z in zones) {
      if (z.type != type) {
        continue;
      }
      final d = GeoMath.distanceMeters(
        position.latitude,
        position.longitude,
        z.lat,
        z.lng,
      );
      if (d <= mergeDistanceM && d < nearestDistance) {
        nearest = z;
        nearestDistance = d;
      }
    }
    if (nearest != null) {
      if (!ignoreRecountWindow &&
          now.difference(nearest.lastSeenAt) < recountAfter) {
        return const ZoneSkipped(ZoneSkipReason.alreadyCounted);
      }
      return ZoneIncremented(
        nearest.copyWith(count: nearest.count + 1, lastSeenAt: now),
      );
    }
    return ZoneCreated(
      RiskZone(
        id: newId(),
        type: type,
        lat: position.latitude,
        lng: position.longitude,
        radiusM: radiusM,
        origin: origin,
        createdAt: now,
        lastSeenAt: now,
      ),
    );
  }
}
