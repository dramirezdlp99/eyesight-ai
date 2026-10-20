import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/device/permission_guard.dart';
import '../../controllers/privacy_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/companion_ui.dart';

/// Privacidad y datos (HU14, RF02, RF20).
class PrivacyView extends GetView<PrivacyController> {
  const PrivacyView({super.key, this.onBack});

  /// Botón «Volver» de la cabecera (vuelve al Mapa).
  final VoidCallback? onBack;

  static String permissionName(AppPermission p) => switch (p) {
        AppPermission.camera => 'Cámara',
        AppPermission.microphone => 'Micrófono',
        AppPermission.location => 'Ubicación',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final perms = Map<AppPermission, bool>.of(controller.permissions);
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          CompanionHeader(
            onBack: onBack,
            title: 'Privacidad',
            subtitle: 'Sus datos no salen de este teléfono. Cifrados con '
                'AES-256; la clave vive en el Android Keystore. Sin cuentas '
                'ni servidores.',
            bottom: Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '${controller.zoneCount.value}',
                    label: 'zonas',
                    background: AppColors.paper,
                    foreground: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: '${controller.historyCount.value}',
                    label: 'alertas',
                    background: AppColors.paper,
                    foreground: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: '${controller.auditCount.value}',
                    label: 'cambios',
                    background: AppColors.paper,
                    foreground: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Permisos',
                  children: [
                    for (final p in AppPermission.values)
                      Semantics(
                        label: '${permissionName(p)}: '
                            '${perms[p] ?? false ? 'concedido' : 'no concedido'}',
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                perms[p] ?? false
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: perms[p] ?? false
                                    ? AppColors.esmeralda
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  permissionName(p),
                                  style: text.titleMedium,
                                ),
                              ),
                              Text(
                                perms[p] ?? false
                                    ? 'Concedido'
                                    : 'No concedido',
                                style: text.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'El mapa descarga el plano de OpenStreetMap; las zonas '
                      'y el historial nunca se envían.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.password),
                  label: const Text('Cambiar PIN'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ChangePinDialog(controller: controller),
                  ),
                ),
                const SizedBox(height: 16),
                _WipeCard(controller: controller),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Borrado total con la palabra de confirmación (HU14, CA2).
class _WipeCard extends StatefulWidget {
  const _WipeCard({required this.controller});

  final PrivacyController controller;

  @override
  State<_WipeCard> createState() => _WipeCardState();
}

class _WipeCardState extends State<_WipeCard> {
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _ready => _typed.text.trim() == PrivacyController.confirmWord;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.carmin,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Borrar todo',
              style: AppText.display(28, color: AppColors.paper),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Elimina zonas, historial, ajustes, PIN y la clave de cifrado. '
            'No se puede deshacer.',
            style: text.bodyLarge?.copyWith(color: AppColors.paper),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _typed,
            textCapitalization: TextCapitalization.characters,
            style: text.titleMedium?.copyWith(color: AppColors.ink),
            decoration: const InputDecoration(
              fillColor: AppColors.paper,
              labelText: 'Escriba ${PrivacyController.confirmWord}',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Obx(() {
            // Se lee primero el valor observable: si solo se leyera cuando
            // _ready es verdadero, GetX no tendría nada que observar.
            final busy = widget.controller.busy.value;
            return FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.paper,
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Borrar mis datos'),
              onPressed: _ready && !busy
                  ? () => widget.controller.wipeAll(_typed.text)
                  : null,
            );
          }),
        ],
      ),
    );
  }
}

/// Cambio de PIN: actual, nuevo y repetición (HU14, CA3).
class ChangePinDialog extends StatefulWidget {
  const ChangePinDialog({super.key, required this.controller});

  final PrivacyController controller;

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: AppConstants.maxPinLength,
          decoration: InputDecoration(labelText: label, counterText: ''),
        ),
      );

  Future<void> _submit() async {
    setState(() => _busy = true);
    final error = await widget.controller.changePin(
      _current.text,
      _next.text,
      _repeat.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('PIN cambiado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: const Text('Cambiar PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_current, 'PIN actual'),
            _field(_next, 'PIN nuevo (4 a 6 dígitos)'),
            _field(_repeat, 'Repita el PIN nuevo'),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}
