import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_constants.dart';
import '../../controllers/pin_controller.dart';

/// PIN del acompañante (wireframe de la HU01, figura b).
class PinView extends GetView<PinController> {
  const PinView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Acompañante')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Obx(
            () => Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    controller.title,
                    textAlign: TextAlign.center,
                    style: text.titleLarge,
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label:
                      '${controller.entered.value.length} dígitos ingresados',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < AppConstants.maxPinLength; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.primary, width: 2),
                            color: i < controller.entered.value.length
                                ? scheme.primary
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.error.value ?? ' ',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(color: scheme.error),
                  ),
                ),
                const Spacer(),
                _Keypad(
                  onDigit: controller.addDigit,
                  onBackspace: controller.backspace,
                  onSubmit: controller.busy.value ? null : controller.submit,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: controller.changeProfile,
                  child: const Text('Cambiar de perfil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback? onTap, {String? semantic}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Semantics(
              button: true,
              label: semantic ?? label,
              excludeSemantics: true,
              child: FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(minimumSize: const Size(64, 64)),
                child: Text(label,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
          ),
        );

    Widget row(List<String> digits) => Row(
          children: [for (final d in digits) key(d, () => onDigit(d))],
        );

    return Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          children: [
            key('⌫', onBackspace, semantic: 'Borrar'),
            key('0', () => onDigit('0')),
            key('OK', onSubmit, semantic: 'Confirmar'),
          ],
        ),
      ],
    );
  }
}
