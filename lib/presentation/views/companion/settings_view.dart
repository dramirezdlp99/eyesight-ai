import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_constants.dart';
import '../../../domain/entities/video_source_kind.dart';
import '../../controllers/settings_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/companion_ui.dart';

/// Ajustes de la herramienta (HU13, RF18, RF19).
class SettingsView extends GetView<SettingsController> {
  const SettingsView({
    super.key,
    required this.onChangeProfile,
    this.onOpenTestMode,
    this.onBack,
  });

  final VoidCallback onChangeProfile;
  final VoidCallback? onOpenTestMode;

  /// Botón «Volver» de la cabecera (vuelve al Mapa).
  final VoidCallback? onBack;

  Future<void> _reset(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: '¿Restablecer los ajustes?',
      body: 'Se recuperan los valores por defecto. Las zonas y el historial '
          'no cambian.',
      confirmLabel: 'Restablecer',
      danger: false,
    );
    if (ok) {
      await controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final s = controller.value.value;
      final message = controller.message.value;
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          CompanionHeader(
            onBack: onBack,
            title: 'Ajustes',
            color: AppColors.ink,
            stepColor: AppColors.inkSoft,
            subtitle: 'Adapte EyeSight AI a la persona que lo usa.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.oro,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          message,
                          style: text.bodyLarge?.copyWith(color: AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                SectionCard(
                  title: 'Voz',
                  children: [
                    SliderSetting(
                      key: ValueKey('rate-${s.speechRate}'),
                      label: 'Velocidad de la voz',
                      value: s.speechRate,
                      min: SettingsController.minRate,
                      max: SettingsController.maxRate,
                      step: SettingsController.rateStep,
                      format: SettingsController.rateLabel,
                      onDone: (v) => controller.setVoice(rate: v),
                    ),
                    SliderSetting(
                      key: ValueKey('volume-${s.volume}'),
                      label: 'Volumen',
                      value: s.volume,
                      min: 0,
                      max: 1,
                      step: 0.05,
                      format: SettingsController.percent,
                      onDone: (v) => controller.setVoice(volume: v),
                    ),
                  ],
                ),
                SectionCard(
                  title: 'Alertas',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibración'),
                      subtitle: const Text('Pulsos según la cercanía'),
                      value: s.vibration,
                      onChanged: controller.setVibration,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Guardar zonas automáticamente'),
                      subtitle:
                          const Text('Huecos, escalones y postes cercanos'),
                      value: s.autoZones,
                      onChanged: controller.setAutoZones,
                    ),
                    SliderSetting(
                      key: ValueKey('radius-${s.alertRadiusM}'),
                      label: 'Radio de alerta',
                      value: s.alertRadiusM,
                      min: AppConstants.minAlertRadiusM,
                      max: AppConstants.maxAlertRadiusM,
                      step: SettingsController.radiusStep,
                      format: (v) => '${v.round()} m',
                      onDone: controller.setRadius,
                    ),
                    SliderSetting(
                      key: ValueKey('confidence-${s.confidenceThreshold}'),
                      label: 'Confianza mínima',
                      value: s.confidenceThreshold,
                      min: AppConstants.minConfidenceThreshold,
                      max: AppConstants.maxConfidenceThreshold,
                      step: SettingsController.confidenceStep,
                      format: SettingsController.confidenceLabel,
                      onDone: controller.setConfidence,
                    ),
                  ],
                ),
                SectionCard(
                  title: 'Cámara',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (kind, label, icon) in const [
                          (
                            VideoSourceKind.phone,
                            'Del teléfono',
                            Icons.smartphone
                          ),
                          (VideoSourceKind.usb, 'USB en gafas', Icons.usb),
                        ])
                          ChoiceChip(
                            avatar: Icon(icon),
                            label: Text(label),
                            selected: s.videoSource == kind,
                            onSelected: (_) => controller.setVideoSource(kind),
                          ),
                      ],
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restablecer'),
                  onPressed: () => _reset(context),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Modo de pruebas'),
                  onPressed: onOpenTestMode ??
                      () => Get.toNamed<void>(AppRoutes.testMode),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Cambiar de perfil'),
                  onPressed: onChangeProfile,
                ),
                const SizedBox(height: 4),
                Text(
                  'Los cambios se guardan solos en este teléfono.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Control deslizante que muestra su valor y guarda al soltarlo.
class SliderSetting extends StatefulWidget {
  const SliderSetting({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onDone,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String Function(double value) format;
  final ValueChanged<double> onDone;

  @override
  State<SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<SliderSetting> {
  late double _value = widget.value.clamp(widget.min, widget.max);

  /// Redondea al paso para evitar valores como 0,35000000001.
  double _snap(double v) {
    final steps = ((v - widget.min) / widget.step).round();
    final snapped = widget.min + steps * widget.step;
    return double.parse(snapped.toStringAsFixed(2))
        .clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = widget.format(_value);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.label, style: text.titleMedium)),
              Text(shown, style: text.titleMedium),
            ],
          ),
          Slider(
            value: _value,
            min: widget.min,
            max: widget.max,
            divisions: ((widget.max - widget.min) / widget.step).round(),
            label: shown,
            semanticFormatterCallback: widget.format,
            onChanged: (v) => setState(() => _value = _snap(v)),
            onChangeEnd: (v) => widget.onDone(_snap(v)),
          ),
        ],
      ),
    );
  }
}
