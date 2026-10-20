import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/security/input_validators.dart';
import '../../../domain/entities/risk_zone.dart';
import '../../../domain/entities/zone_origin.dart';
import '../../controllers/zones_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/companion_ui.dart';

/// Edición y eliminación de una zona de riesgo (HU11, RF16).
class EditZoneView extends StatefulWidget {
  const EditZoneView({super.key, required this.zoneId, this.onDone});

  final String zoneId;

  /// Al guardar o eliminar; por defecto vuelve a la pantalla anterior.
  final VoidCallback? onDone;

  @override
  State<EditZoneView> createState() => _EditZoneViewState();
}

class _EditZoneViewState extends State<EditZoneView> {
  ZonesController get controller => Get.find<ZonesController>();

  late final RiskZone? _zone = controller.byId(widget.zoneId);
  late String _type = _initialType();
  late double _radius = _zone?.radiusM ?? AppConstants.defaultAlertRadiusM;
  late final TextEditingController _note =
      TextEditingController(text: _zone?.note ?? '');
  String? _error;
  bool _busy = false;

  String _initialType() {
    final type = _zone?.type ?? 'other';
    return ZonesController.zoneTypes.contains(type) ? type : 'other';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done() {
    final done = widget.onDone;
    if (done != null) {
      done();
    } else {
      Get.back<void>();
    }
  }

  Future<void> _save() async {
    final noteError = InputValidators.note(_note.text);
    if (noteError != null) {
      setState(() => _error = noteError);
      return;
    }
    setState(() => _busy = true);
    final error = await controller.save(
      widget.zoneId,
      type: _type,
      radiusM: _radius,
      note: _note.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) {
      showNotice(context, 'Zona actualizada.');
      _done();
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: '¿Eliminar esta zona?',
      body: 'Dejará de generar alertas. No se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!ok || !mounted) {
      return;
    }
    await controller.delete(widget.zoneId);
    if (!mounted) {
      return;
    }
    showNotice(context, 'Zona eliminada.');
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final zone = _zone;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (zone == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar zona')),
        body: const Center(child: Text('La zona ya no existe.')),
      );
    }
    final automatic = zone.origin == ZoneOrigin.automatic;
    final noteLength = _note.text.length;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CompanionHeader(
            title: 'Editar zona',
            color: automatic ? AppColors.carmin : AppColors.esmeralda,
            stepColor:
                automatic ? AppColors.carminDeep : AppColors.esmeraldaDeep,
            subtitle: '${automatic ? 'Automática' : 'Manual'} · ${zone.count} '
                '${zone.count == 1 ? 'registro' : 'registros'}',
            trailing: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.close, color: AppColors.paper),
              onPressed: _done,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Tipo de riesgo',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in ZonesController.zoneTypes)
                          ChoiceChip(
                            label: Text(ZonesController.typeName(t)),
                            selected: t == _type,
                            onSelected: (_) => setState(() => _type = t),
                          ),
                      ],
                    ),
                  ],
                ),
                SectionCard(
                  title: 'Radio de alerta',
                  children: [
                    Text(
                      '${_radius.round()} m',
                      style: text.headlineSmall,
                    ),
                    Slider(
                      value: _radius.clamp(
                        AppConstants.minAlertRadiusM,
                        AppConstants.maxAlertRadiusM,
                      ),
                      min: AppConstants.minAlertRadiusM,
                      max: AppConstants.maxAlertRadiusM,
                      divisions: ((AppConstants.maxAlertRadiusM -
                                  AppConstants.minAlertRadiusM) /
                              5)
                          .round(),
                      label: '${_radius.round()} m',
                      semanticFormatterCallback: (v) => '${v.round()} metros',
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                    Text(
                      'De ${AppConstants.minAlertRadiusM.round()} a '
                      '${AppConstants.maxAlertRadiusM.round()} metros.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SectionCard(
                  title: 'Nota',
                  children: [
                    TextField(
                      controller: _note,
                      maxLines: 3,
                      minLines: 1,
                      maxLength: AppConstants.maxNoteLength,
                      // Se deja escribir de más para mostrar el error (CA2).
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Por ejemplo: andén roto frente a la tienda',
                        errorText: noteLength > AppConstants.maxNoteLength
                            ? InputValidators.note(_note.text)
                            : null,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: text.bodyLarge?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar cambios'),
                  onPressed: _busy ? null : _save,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar zona'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error, width: 2),
                  ),
                  onPressed: _busy ? null : _delete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
