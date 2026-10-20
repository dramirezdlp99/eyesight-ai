import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ai/obstacle_catalog.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/device/phone_camera_source.dart';
import '../../../domain/entities/detection.dart';
import '../../../domain/entities/proximity.dart';
import '../../../domain/entities/risk_zone.dart';
import '../../../domain/usecases/zone_monitor.dart';
import '../../controllers/scanner_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/detection_overlay.dart';
import '../../widgets/eye_logo.dart';
import '../../widgets/motion.dart';
import '../../widgets/scanner_gestures.dart';

/// Escáner del usuario final (HU02 a HU09), diseño «Barniz de Pasto».
///
/// * Ceguera total: la cámara con las cajas detectadas, la tarjeta de la
///   última alerta y los gestos sobre toda el área (RNF08).
/// * Baja visión: fondo negro, el aviso en letra muy grande y cuatro botones
///   grandes: Repetir, Silenciar, Marcar zona y Terminar (HU05).
class ScannerView extends GetView<ScannerController> {
  const ScannerView({super.key, required this.onChangeProfile});

  final VoidCallback onChangeProfile;

  bool get _lowVision =>
      Get.isRegistered<ThemeController>() &&
      Get.find<ThemeController>().highContrast;

  @override
  Widget build(BuildContext context) {
    final lowVision = _lowVision;
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          final state = controller.state.value;
          if (state == ScanState.stopped || state == ScanState.failed) {
            return _StoppedPanel(
              controller: controller,
              failed: state == ScanState.failed,
              lowVision: lowVision,
              onChangeProfile: onChangeProfile,
            );
          }
          final dialog = controller.dialog.value;
          return Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(controller: controller, lowVision: lowVision),
                    Expanded(
                      child: ScannerGestures(
                        onDoubleTap: controller.repeat,
                        onSwipe: controller.mute,
                        onLongPress: controller.markZone,
                        onStop: controller.requestStop,
                        child: lowVision
                            ? _LowVisionBody(controller: controller)
                            : _BlindBody(controller: controller),
                      ),
                    ),
                    if (lowVision)
                      _LowVisionButtons(controller: controller)
                    else
                      const _GestureHelp(),
                  ],
                ),
              ),
              if (dialog != ScannerDialog.none)
                Positioned.fill(
                  child: _DialogSheet(controller: controller, dialog: dialog),
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------- Partes

/// Título, perfil y estado.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.lowVision});

  final ScannerController controller;
  final bool lowVision;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (!lowVision) ...[
            Obx(
              () => EyeLogo(
                size: 40,
                animate: controller.state.value == ScanState.scanning,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Semantics(
            header: true,
            child: Text(
              'Escáner',
              style: AppText.display(
                lowVision ? 34 : 26,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Obx(
                () => Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (lowVision)
                      const _Chip(
                        label: 'Baja visión',
                        background: AppColors.oro,
                        foreground: AppColors.ink,
                      ),
                    if (controller.muted.value)
                      const _Chip(
                        label: 'Silencio',
                        icon: Icons.volume_off,
                        background: AppColors.oro,
                        foreground: AppColors.ink,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ceguera total: cámara, aviso de zona guardada y tarjeta de alerta.
class _BlindBody extends StatelessWidget {
  const _BlindBody({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _CameraPanel(controller: controller)),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Obx(() => _SavedZoneToast(
                        zone: controller.savedZone.value,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => _AlertCard.of(controller, lowVision: false)),
        ],
      ),
    );
  }
}

/// Baja visión: el aviso ocupa la pantalla.
class _LowVisionBody extends StatelessWidget {
  const _LowVisionBody({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusLine(controller: controller),
          const SizedBox(height: 12),
          Expanded(
            child: Obx(
              () => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AlertCard.of(controller, lowVision: true),
                    const SizedBox(height: 12),
                    _SavedZoneToast(zone: controller.savedZone.value),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista de la cámara con la franja de trayectoria, las cajas y un barrido
/// que indica que el modelo está analizando (HU02, HU03).
class _CameraPanel extends StatelessWidget {
  const _CameraPanel({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: AppColors.night,
          child: Obx(() {
            final detections = controller.detections.toList();
            final scanning = controller.state.value == ScanState.scanning;
            return Stack(
              fit: StackFit.expand,
              children: [
                _Preview(controller: controller, detections: detections),
                if (scanning) const ScanSweep(color: AppColors.paper),
                // Abajo, para no tapar las etiquetas de lo que está al frente.
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        label: controller.status.value,
                        icon: Icons.circle,
                        iconColor:
                            scanning ? AppColors.esmeralda : AppColors.oro,
                        background: AppColors.paper,
                        foreground: AppColors.ink,
                      ),
                      _Chip(
                        label: controller.gpsReady.value ? 'GPS' : 'Sin GPS',
                        icon: controller.gpsReady.value
                            ? Icons.gps_fixed
                            : Icons.gps_off,
                        background: AppColors.ink,
                        foreground: AppColors.paper,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Imagen de la cámara del teléfono, recortada para llenar el panel, con
/// las cajas alineadas a la misma imagen. Con la cámara USB o en pruebas se
/// dibujan solo las cajas.
class _Preview extends StatelessWidget {
  const _Preview({required this.controller, required this.detections});

  final ScannerController controller;
  final List<Detection> detections;

  @override
  Widget build(BuildContext context) {
    final overlay = DetectionOverlay(detections: detections, announce: false);
    final source = controller.videoSource;
    final camera = source is PhoneCameraSource ? source.controller : null;
    if (camera == null || !camera.value.isInitialized) {
      return overlay;
    }
    // La cámara entrega la imagen horizontal; en vertical se invierte.
    const width = 300.0;
    final height = width * camera.value.aspectRatio;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [CameraPreview(camera), overlay],
        ),
      ),
    );
  }
}

/// Tarjeta del último aviso: obstáculo (color según la cercanía), zona de
/// riesgo (oro con ondas) o en espera.
class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.headline,
    required this.proximity,
    required this.zone,
    required this.lowVision,
  });

  factory _AlertCard.of(ScannerController c, {required bool lowVision}) =>
      _AlertCard(
        headline: c.headline.value,
        proximity: c.headlineProximity.value,
        zone: c.headlineProximity.value == null ? c.activeZone.value : null,
        lowVision: lowVision,
      );

  final String headline;
  final Proximity? proximity;
  final ZoneWarning? zone;
  final bool lowVision;

  /// Pulsos de vibración de cada cercanía (HU04).
  static int pulses(Proximity p) => switch (p) {
        Proximity.near => 3,
        Proximity.medium => 2,
        Proximity.far => 1,
      };

  static String pulseText(Proximity p) => switch (p) {
        Proximity.near => 'Cerca · vibra 3 veces',
        Proximity.medium => 'Media distancia · vibra 2 veces',
        Proximity.far => 'Lejos · vibra 1 vez',
      };

  @override
  Widget build(BuildContext context) {
    final z = zone;
    final p = proximity;
    final Widget card;
    if (headline.isEmpty) {
      card = _idle(context);
    } else if (z != null) {
      card = _zoneCard(context, z);
    } else {
      card = _obstacleCard(context, p);
    }
    return Semantics(
      label: headline.isEmpty ? 'Sin alertas por ahora' : headline,
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: reduceMotionOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(headline), child: card),
      ),
    );
  }

  Widget _box({
    required Color color,
    required Widget child,
    BoxBorder? border,
  }) =>
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(lowVision ? 24 : 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          border: border,
        ),
        child: child,
      );

  Widget _idle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _box(
      color: scheme.surfaceContainerHighest,
      border: lowVision ? Border.all(color: AppColors.paper, width: 3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sin alertas por ahora',
            style: AppText.display(
              lowVision ? 34 : 26,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Camine con su bastón; le aviso por voz y vibración.',
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _obstacleCard(BuildContext context, Proximity? p) {
    final text = Theme.of(context).textTheme;
    final background = p == null ? AppColors.cobalt : AppColors.forProximity(p);
    final foreground = p == null ? AppColors.paper : AppColors.onProximity(p);
    final cut = headline.indexOf(', ');
    final name = cut < 0 ? headline : headline.substring(0, cut);
    final detail = cut < 0 ? '' : headline.substring(cut + 2);
    return _box(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p != null)
            Row(
              children: [
                PulseDots(count: pulses(p), color: foreground, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pulseText(p),
                    style: text.titleMedium?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              name,
              style: AppText.display(lowVision ? 76 : 60, color: foreground),
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: AppText.display(lowVision ? 32 : 24, color: foreground),
            ),
          ],
        ],
      ),
    );
  }

  Widget _zoneCard(BuildContext context, ZoneWarning z) {
    final text = Theme.of(context).textTheme;
    final name = ObstacleCatalog.spanishName(z.zone.type);
    return _box(
      color: AppColors.oro,
      child: Row(
        children: [
          RadarRings(
            color: AppColors.ink.withValues(alpha: 0.5),
            size: lowVision ? 92 : 76,
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.ink,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atención, zona de riesgo',
                  style: text.titleMedium?.copyWith(color: AppColors.ink),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: AppText.display(
                      lowVision ? 56 : 44,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  'a ${z.distanceM.round()} m · un pulso largo',
                  style: text.titleMedium?.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso verde de zona guardada (HU06, HU07). Se desvanece solo.
class _SavedZoneToast extends StatefulWidget {
  const _SavedZoneToast({required this.zone});

  final RiskZone? zone;

  @override
  State<_SavedZoneToast> createState() => _SavedZoneToastState();
}

class _SavedZoneToastState extends State<_SavedZoneToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    super.initState();
    if (widget.zone != null) {
      _life.forward();
    }
  }

  @override
  void didUpdateWidget(_SavedZoneToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    final zone = widget.zone;
    final old = oldWidget.zone;
    if (zone != null &&
        (old == null || old.id != zone.id || old.count != zone.count)) {
      _life.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    if (zone == null) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final name = ObstacleCatalog.spanishName(zone.type).toLowerCase();
    return AnimatedBuilder(
      animation: _life,
      builder: (context, child) {
        final t = _life.value;
        // Aparece rápido, se mantiene y se desvanece al final.
        final opacity = t < 0.08 ? t / 0.08 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
        if (!_life.isAnimating && t >= 1) {
          return const SizedBox.shrink();
        }
        return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.esmeralda,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.paper),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Zona de $name guardada',
                style: text.titleMedium?.copyWith(color: AppColors.paper),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado y métricas en una línea (baja visión).
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final scanning = controller.state.value == ScanState.scanning;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip(
            label: scanning ? 'Activo' : controller.status.value,
            icon: Icons.circle,
            iconColor: scanning ? AppColors.esmeralda : AppColors.oro,
            background: AppColors.paper,
            foreground: AppColors.ink,
          ),
          _Chip(
            label: controller.gpsReady.value ? 'GPS' : 'Sin GPS',
            icon: controller.gpsReady.value ? Icons.gps_fixed : Icons.gps_off,
            background: AppColors.paper,
            foreground: AppColors.ink,
          ),
        ],
      );
    });
  }
}

/// Botones grandes del perfil de baja visión (HU05, CA2).
class _LowVisionButtons extends StatelessWidget {
  const _LowVisionButtons({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              _BigButton(
                label: 'Repetir',
                icon: Icons.replay,
                onPressed: controller.repeat,
              ),
              _BigButton(
                label: 'Silenciar',
                icon: Icons.volume_off,
                onPressed: controller.mute,
              ),
            ],
          ),
          Row(
            children: [
              _BigButton(
                label: 'Marcar zona',
                icon: Icons.add_location_alt,
                onPressed: controller.markZone,
              ),
              _BigButton(
                label: 'Terminar',
                icon: Icons.stop_circle_outlined,
                onPressed: controller.requestStop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recordatorio de los tres gestos (ceguera total).
class _GestureHelp extends StatelessWidget {
  const _GestureHelp();

  static const List<(IconData, String, String)> gestures = [
    (Icons.touch_app, 'Doble toque', 'repetir'),
    (Icons.swipe, 'Deslizar', 'silenciar 10\u00A0s'),
    (Icons.pan_tool_alt, 'Mantener 2\u00A0s', 'marcar zona'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, title, action) in gestures)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Icon(icon, color: scheme.primary),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: text.labelLarge?.copyWith(fontSize: 14),
                    ),
                    Text(
                      action,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hoja inferior de la pregunta por voz en curso: tipo de zona (HU07) o
/// confirmación para terminar (HU09, CA3).
class _DialogSheet extends StatelessWidget {
  const _DialogSheet({required this.controller, required this.dialog});

  final ScannerController controller;
  final ScannerDialog dialog;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final zone = dialog == ScannerDialog.zoneType;
    final List<Widget> options;
    if (zone) {
      options = [
        Row(
          children: [
            _BigButton(
              label: 'Hueco',
              onPressed: () => controller.markZone('pothole'),
            ),
            _BigButton(
              label: 'Escalón',
              onPressed: () => controller.markZone('step'),
            ),
          ],
        ),
        Row(
          children: [
            _BigButton(
              label: 'Obra',
              onPressed: () => controller.markZone('construction'),
            ),
            _BigButton(
              label: 'Otro',
              onPressed: () => controller.markZone('other'),
            ),
          ],
        ),
        Row(
          children: [
            _BigButton(
              label: 'Cancelar',
              outlined: true,
              onPressed: controller.cancelZone,
            ),
          ],
        ),
      ];
    } else {
      options = [
        Row(
          children: [
            _BigButton(
              label: 'Sí, terminar',
              danger: true,
              onPressed: () => controller.confirmStop(true),
            ),
            _BigButton(
              label: 'No, seguir',
              outlined: true,
              onPressed: () => controller.confirmStop(false),
            ),
          ],
        ),
      ];
    }
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              side: BorderSide(color: scheme.outline),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        if (zone && controller.voiceReady) ...[
                          CountdownRing(
                            duration: AppConstants.manualZoneAnswerTimeout,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (zone)
                                Text(
                                  'Marcando zona aquí',
                                  style: text.titleMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              Semantics(
                                header: true,
                                child: Text(
                                  zone
                                      ? '¿Qué tipo de riesgo es?'
                                      : '¿Terminar el escáner?',
                                  style: AppText.display(
                                    28,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      zone
                          ? 'Diga: hueco, escalón, obra u otro.'
                          : 'Diga sí o no.',
                      style: text.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...options,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Escáner detenido o con falla: resumen de la sesión y acciones.
class _StoppedPanel extends StatelessWidget {
  const _StoppedPanel({
    required this.controller,
    required this.failed,
    required this.lowVision,
    required this.onChangeProfile,
  });

  final ScannerController controller;
  final bool failed;
  final bool lowVision;
  final VoidCallback onChangeProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Obx(() {
      final minutes = controller.sessionLength.value.inMinutes;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Center(child: EyeLogo(size: 112, animate: false, closed: !failed)),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              controller.status.value,
              textAlign: TextAlign.center,
              style: AppText.display(34, color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            failed
                ? 'Use su bastón con precaución.'
                : 'La cámara y el GPS están apagados.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (!failed) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                _Stat(value: '$minutes min', label: 'de recorrido'),
                _Stat(
                  value: '${controller.alertCount.value}',
                  label: 'alertas',
                ),
                _Stat(
                  value: '${controller.zoneCount.value}',
                  label: 'zonas nuevas',
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(failed ? 'Reintentar' : 'Iniciar escáner'),
            onPressed: controller.startScan,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Cambiar de perfil'),
            onPressed: onChangeProfile,
          ),
        ],
      );
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppText.display(26, color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta pequeña de estado.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.iconColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final i = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i != null) ...[
            Icon(i, size: 14, color: iconColor ?? foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de al menos 56 dp de alto que ocupa la mitad de la fila (RNF07).
class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool outlined;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;
    // Una sola línea que se ajusta al ancho: la palabra nunca se parte.
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, textAlign: TextAlign.center),
    );
    final Widget child = iconData == null
        ? text
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 30),
              const SizedBox(height: 4),
              text
            ],
          );
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 12);
    final Widget button;
    if (outlined) {
      button = OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(padding: padding),
        child: child,
      );
    } else {
      button = FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: padding,
          backgroundColor: danger ? AppColors.carmin : null,
          foregroundColor: danger ? AppColors.paper : null,
        ),
        child: child,
      );
    }
    return Expanded(
      child: Padding(padding: const EdgeInsets.all(5), child: button),
    );
  }
}
