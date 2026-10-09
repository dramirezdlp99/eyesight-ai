import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/entities/proximity.dart';
import '../../controllers/scanner_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/eye_logo.dart';
import '../../widgets/scanner_gestures.dart';

/// Escáner del usuario final (HU02 a HU09).
///
/// * Ceguera total: toda la pantalla recibe los gestos; la información
///   llega por voz y vibración (RNF08).
/// * Baja visión: además muestra el último aviso en texto grande de alto
///   contraste y los botones Repetir, Silenciar, Marcar zona y Terminar
///   (HU05).
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
      appBar: AppBar(
        title: const Text('Escáner'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Obx(() {
          final state = controller.state.value;
          if (state == ScanState.stopped || state == ScanState.failed) {
            return _StoppedPanel(
              failed: state == ScanState.failed,
              status: controller.status.value,
              onStart: controller.startScan,
              onChangeProfile: onChangeProfile,
            );
          }
          final dialog = controller.dialog.value;
          final gestures = ScannerGestures(
            onDoubleTap: controller.repeatLast,
            onSwipe: controller.mute,
            onLongPress: controller.markZone,
            onStop: controller.requestStop,
            child: _AlertPanel(controller: controller, lowVision: lowVision),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: gestures),
              if (dialog != ScannerDialog.none)
                _DialogOptions(controller: controller, dialog: dialog)
              else if (lowVision)
                _LowVisionButtons(controller: controller)
              else
                const _GestureHelp(),
            ],
          );
        }),
      ),
    );
  }
}

/// Último aviso, estado y métricas.
class _AlertPanel extends StatelessWidget {
  const _AlertPanel({required this.controller, required this.lowVision});

  final ScannerController controller;
  final bool lowVision;

  static Color colorFor(Proximity? p, ColorScheme scheme) => switch (p) {
        Proximity.near => AppColors.alertNear,
        Proximity.medium => AppColors.alertMedium,
        Proximity.far => AppColors.alertFar,
        null => scheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final scanning = controller.state.value == ScanState.scanning;
      final headline = controller.headline.value;
      final proximity = controller.headlineProximity.value;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EyeLogo(size: lowVision ? 96 : 140, animate: scanning),
              const SizedBox(height: 12),
              Text(
                controller.status.value,
                textAlign: TextAlign.center,
                style: text.titleLarge,
              ),
              if (controller.muted.value)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Voz en silencio',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                ),
              const SizedBox(height: 20),
              if (headline.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorFor(proximity, scheme),
                      width: lowVision ? 6 : 3,
                    ),
                  ),
                  child: Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium,
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Cuadros por segundo: ${controller.fps.value.toStringAsFixed(1)}'
                ' · Inferencia: ${controller.inferenceMs.value} ms',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _BigButton(
                label: 'Repetir',
                icon: Icons.replay,
                onPressed: controller.repeatLast,
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
                icon: Icons.stop_circle,
                onPressed: controller.requestStop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opciones en pantalla de la pregunta por voz en curso.
class _DialogOptions extends StatelessWidget {
  const _DialogOptions({required this.controller, required this.dialog});

  final ScannerController controller;
  final ScannerDialog dialog;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final List<Widget> rows;
    final String question;
    if (dialog == ScannerDialog.zoneType) {
      question = '¿Qué tipo de riesgo?';
      rows = [
        Row(
          children: [
            _BigButton(
              label: 'Hueco',
              onPressed: () => controller.chooseZoneType('pothole'),
            ),
            _BigButton(
              label: 'Escalón',
              onPressed: () => controller.chooseZoneType('step'),
            ),
          ],
        ),
        Row(
          children: [
            _BigButton(
              label: 'Obra',
              onPressed: () => controller.chooseZoneType('construction'),
            ),
            _BigButton(
              label: 'Otro',
              onPressed: () => controller.chooseZoneType('other'),
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
      question = '¿Terminar el escáner?';
      rows = [
        Row(
          children: [
            _BigButton(
              label: 'Sí, terminar',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              question,
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

/// Recordatorio de los gestos para el perfil de ceguera total.
class _GestureHelp extends StatelessWidget {
  const _GestureHelp();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Text(
        'Doble toque: repetir · Desliza: silenciar · '
        'Mantén 2 s: marcar zona · Di «terminar» para salir',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// Escáner detenido o con falla: permite reiniciar o cambiar de perfil.
class _StoppedPanel extends StatelessWidget {
  const _StoppedPanel({
    required this.failed,
    required this.status,
    required this.onStart,
    required this.onChangeProfile,
  });

  final bool failed;
  final String status;
  final VoidCallback onStart;
  final VoidCallback onChangeProfile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: EyeLogo(size: 120, animate: false)),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child:
              Text(status, textAlign: TextAlign.center, style: text.titleLarge),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(failed ? 'Reintentar' : 'Iniciar escáner'),
          onPressed: onStart,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Cambiar de perfil'),
          onPressed: onChangeProfile,
        ),
      ],
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
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;
    final child = Text(label, textAlign: TextAlign.center);
    final Widget button;
    if (outlined) {
      button = OutlinedButton(onPressed: onPressed, child: child);
    } else if (iconData != null) {
      button = FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(iconData),
        label: child,
      );
    } else {
      button = FilledButton(onPressed: onPressed, child: child);
    }
    return Expanded(
      child: Padding(padding: const EdgeInsets.all(6), child: button),
    );
  }
}
