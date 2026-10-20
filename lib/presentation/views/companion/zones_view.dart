import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/entities/risk_zone.dart';
import '../../../domain/entities/zone_origin.dart';
import '../../controllers/zones_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/companion_ui.dart';

/// Mapa y lista de zonas de riesgo (HU10, RF15).
///
/// Las zonas y la lista funcionan sin internet; solo el mapa base
/// (OpenStreetMap) necesita conexión (HU10, CA2).
class ZonesView extends GetView<ZonesController> {
  const ZonesView({super.key, this.baseMap = true, this.onOpenZone});

  /// `false` en las pruebas: no se descargan teselas.
  final bool baseMap;

  /// Abre la edición de una zona (HU10, CA4).
  final void Function(String id)? onOpenZone;

  /// Centro de Pasto, si no hay zonas ni ubicación.
  static const LatLng pasto = LatLng(1.2136, -77.2811);

  static Color colorFor(ZoneOrigin origin) => switch (origin) {
        ZoneOrigin.automatic => AppColors.carmin,
        ZoneOrigin.manual => AppColors.esmeralda,
      };

  void _open(String id) {
    final open = onOpenZone;
    if (open != null) {
      open(id);
    } else {
      Get.toNamed<void>(AppRoutes.editZone, arguments: id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final zones = controller.visible;
      final loading = controller.loading.value;
      final filter = controller.filter.value;
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            CompanionHeader(
              eyebrow: 'Hola, acompañante',
              title: 'Zonas de riesgo',
              bottom: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '${controller.automaticCount}',
                      label: 'automáticas',
                      background: AppColors.paper,
                      foreground: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      value: '${controller.manualCount}',
                      label: 'manuales',
                      background: AppColors.paper,
                      foreground: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in ZoneFilter.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: f == filter,
                      onSelected: (_) => controller.setFilter(f),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  height: 260,
                  child: _ZonesMap(
                    zones: zones,
                    baseMap: baseMap,
                    user: controller.position.value == null
                        ? null
                        : LatLng(
                            controller.position.value!.latitude,
                            controller.position.value!.longitude,
                          ),
                    onOpen: _open,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Semantics(
                header: true,
                child: Text(
                  'Lista de zonas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (zones.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Text(
                  filter == ZoneFilter.all
                      ? 'Aún no hay zonas. Se guardan solas al detectar un '
                          'riesgo cerca, o al marcarlas por voz o con un gesto.'
                      : 'No hay zonas ${filter.label.toLowerCase()}.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            else
              for (final z in zones)
                _ZoneTile(
                  zone: z,
                  subtitle:
                      '${z.origin == ZoneOrigin.automatic ? 'Automática' : 'Manual'}'
                      ' · ${z.count} ${z.count == 1 ? 'registro' : 'registros'}'
                      ' · ${controller.ago(z.lastSeenAt)}',
                  distance: controller.distanceTo(z),
                  onTap: () => _open(z.id),
                ),
            const SizedBox(height: 24),
          ],
        ),
      );
    });
  }
}

class _ZonesMap extends StatelessWidget {
  const _ZonesMap({
    required this.zones,
    required this.baseMap,
    required this.user,
    required this.onOpen,
  });

  final List<RiskZone> zones;
  final bool baseMap;
  final LatLng? user;
  final void Function(String id) onOpen;

  LatLng get center {
    final u = user;
    if (u != null) {
      return u;
    }
    if (zones.isEmpty) {
      return ZonesView.pasto;
    }
    final lat = zones.map((z) => z.lat).reduce((a, b) => a + b) / zones.length;
    final lng = zones.map((z) => z.lng).reduce((a, b) => a + b) / zones.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = user;
    return Semantics(
      label: 'Mapa con ${zones.length} zonas. La lista de abajo tiene la '
          'misma información.',
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: FlutterMap(
          // La clave cambia con las zonas para volver a centrar el mapa.
          key: ValueKey('${zones.length}-${u?.latitude}'),
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            if (baseMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'co.edu.ucc.eyesight_ai',
              ),
            CircleLayer(
              circles: [
                for (final z in zones)
                  CircleMarker(
                    point: LatLng(z.lat, z.lng),
                    radius: z.radiusM,
                    useRadiusInMeter: true,
                    color: ZonesView.colorFor(z.origin).withValues(alpha: 0.18),
                    borderColor: ZonesView.colorFor(z.origin),
                    borderStrokeWidth: 2,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final z in zones)
                  Marker(
                    point: LatLng(z.lat, z.lng),
                    width: 48,
                    height: 48,
                    child: _ZoneMarker(zone: z, onTap: () => onOpen(z.id)),
                  ),
                if (u != null)
                  Marker(
                    point: u,
                    width: 26,
                    height: 26,
                    child: Semantics(
                      label: 'Usted está aquí',
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.cobalt,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.paper, width: 4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (baseMap)
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoneMarker extends StatelessWidget {
  const _ZoneMarker({required this.zone, required this.onTap});

  final RiskZone zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ZonesView.colorFor(zone.origin);
    return Semantics(
      button: true,
      label:
          '${ZonesController.typeName(zone.type)}, ${zone.origin.spanishName}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.paper, width: 3),
          ),
          child: Icon(
            zone.origin == ZoneOrigin.automatic
                ? Icons.warning_amber_rounded
                : Icons.push_pin,
            color: AppColors.paper,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.zone,
    required this.subtitle,
    required this.distance,
    required this.onTap,
  });

  final RiskZone zone;
  final String subtitle;
  final double? distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = ZonesView.colorFor(zone.origin);
    final d = distance;
    final name = ZonesController.typeName(zone.type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Semantics(
        button: true,
        label: '$name. $subtitle${d == null ? '' : '. A ${d.round()} metros'}. '
            'Toque para editar.',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        zone.origin == ZoneOrigin.automatic
                            ? Icons.warning_amber_rounded
                            : Icons.push_pin,
                        color: AppColors.paper,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style:
                                  AppText.display(22, color: scheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (d != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '${d.round()} m',
                          style: text.titleMedium,
                        ),
                      ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
