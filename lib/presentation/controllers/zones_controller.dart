import 'package:get/get.dart';

import '../../core/ai/obstacle_catalog.dart';
import '../../core/device/location_service.dart';
import '../../core/device/permission_guard.dart';
import '../../domain/entities/geo_position.dart';
import '../../domain/entities/risk_zone.dart';
import '../../domain/entities/zone_origin.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../../domain/usecases/geo_math.dart';
import '../../domain/usecases/zone_service.dart';

/// Filtro de origen de la lista y el mapa de zonas (HU10, CA3).
enum ZoneFilter {
  all('Todas'),
  automatic('Automáticas'),
  manual('Manuales');

  const ZoneFilter(this.label);

  final String label;

  bool accepts(RiskZone zone) => switch (this) {
        ZoneFilter.all => true,
        ZoneFilter.automatic => zone.origin == ZoneOrigin.automatic,
        ZoneFilter.manual => zone.origin == ZoneOrigin.manual,
      };
}

/// Mapa, lista, edición y eliminación de zonas de riesgo (HU10 y HU11;
/// diagrama de clases: ZonesController).
class ZonesController extends GetxController {
  ZonesController({
    required IZoneRepository zones,
    required ZoneService service,
    required ILocationService location,
    required IPermissionGuard permissions,
    DateTime Function()? clock,
  })  : _zones = zones,
        _service = service,
        _location = location,
        _permissions = permissions,
        _clock = clock ?? DateTime.now;

  final IZoneRepository _zones;
  final ZoneService _service;
  final ILocationService _location;
  final IPermissionGuard _permissions;
  final DateTime Function() _clock;

  /// Tipos que se pueden asignar a una zona (HU11, CA1).
  static const List<String> zoneTypes = [
    'pothole',
    'step',
    'pole',
    'bollard',
    'construction',
    'other',
  ];

  final RxList<RiskZone> zones = <RiskZone>[].obs;
  final Rx<ZoneFilter> filter = ZoneFilter.all.obs;
  final Rxn<GeoPosition> position = Rxn<GeoPosition>();
  final RxBool loading = true.obs;

  /// Zonas que cumplen el filtro, de la más reciente a la más antigua.
  List<RiskZone> get visible => [
        for (final z in zones)
          if (filter.value.accepts(z)) z
      ]..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

  int get automaticCount =>
      zones.where((z) => z.origin == ZoneOrigin.automatic).length;

  int get manualCount =>
      zones.where((z) => z.origin == ZoneOrigin.manual).length;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Carga las zonas guardadas. No necesita internet (HU10, CA2).
  Future<void> load() async {
    loading.value = true;
    zones.assignAll(await _zones.all());
    loading.value = false;
    await _locate();
  }

  /// Ubicación del acompañante para centrar el mapa y medir distancias. Solo
  /// se consulta si el permiso ya fue concedido: aquí no se pide.
  Future<void> _locate() async {
    try {
      if (await _permissions.isGranted(AppPermission.location)) {
        position.value = await _location.current();
      }
    } on Object {
      position.value = null;
    }
  }

  void setFilter(ZoneFilter value) => filter.value = value;

  RiskZone? byId(String id) {
    for (final z in zones) {
      if (z.id == id) {
        return z;
      }
    }
    return null;
  }

  /// Distancia en metros desde la posición actual, si se conoce.
  double? distanceTo(RiskZone zone) {
    final p = position.value;
    if (p == null) {
      return null;
    }
    return GeoMath.distanceMeters(p.latitude, p.longitude, zone.lat, zone.lng);
  }

  /// «hace 2 días», «ayer», «hoy».
  String ago(DateTime when) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final days = today.difference(day).inDays;
    if (days <= 0) {
      return 'hoy';
    }
    if (days == 1) {
      return 'ayer';
    }
    return 'hace $days días';
  }

  /// Guarda los cambios (HU11, CA1 y CA2). Devuelve `null` si se guardó o
  /// el mensaje de error.
  Future<String?> save(
    String id, {
    required String type,
    required double radiusM,
    required String note,
  }) async {
    final error = await _service.edit(
      id,
      type: type,
      radiusM: radiusM,
      note: note,
    );
    if (error == null) {
      await load();
    }
    return error;
  }

  /// Elimina la zona; deja de generar alertas (HU11, CA3).
  Future<bool> delete(String id) async {
    final deleted = await _service.delete(id);
    await load();
    return deleted;
  }

  static String typeName(String type) => ObstacleCatalog.spanishName(type);
}
