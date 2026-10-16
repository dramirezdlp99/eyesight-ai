import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_constants.dart';
import '../../controllers/pin_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/greca.dart';

/// PIN del acompañante (HU01 CA3, RNF10), diseño «Barniz de Pasto».
class PinView extends GetView<PinController> {
  const PinView({super.key});

  static String get rules =>
      'De ${AppConstants.minPinLength} a ${AppConstants.maxPinLength} '
      'dígitos · ${AppConstants.maxPinAttempts} intentos antes de esperar '
      '${AppConstants.pinLockDuration.inSeconds} s';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Obx(
        () => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: controller.title,
                count: controller.entered.value.length,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.error.value ?? ' ',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _Keypad(
                  onDigit: controller.addDigit,
                  onBackspace: controller.backspace,
                  onSubmit: controller.busy.value ? null : controller.submit,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: TextButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: controller.changeProfile,
                  label: const Text('Cambiar de perfil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera esmeralda con la greca, el título y los puntos del PIN.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: ColoredBox(
        color: AppColors.esmeralda,
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              right: 0,
              child: GrecaCorner(
                color: AppColors.esmeraldaDeep,
                accent: AppColors.oro,
                width: 120,
                height: 88,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.supervisor_account,
                          color: AppColors.paper,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Acompañante',
                          style: text.titleMedium?.copyWith(
                            color: AppColors.paper,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: AppText.display(34, color: AppColors.paper),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      PinView.rules,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.paper,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: '$count dígitos ingresados',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          for (var i = 0; i < AppConstants.maxPinLength; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 12),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < count ? AppColors.paper : null,
                                border: Border.all(
                                  color: AppColors.paper,
                                  width: 2.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    final scheme = Theme.of(context).colorScheme;
    Widget key(
      Widget child,
      VoidCallback? onTap, {
      required String semantic,
      Color? background,
      Color? foreground,
    }) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Semantics(
              button: true,
              label: semantic,
              excludeSemantics: true,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 64),
                  backgroundColor: background ?? scheme.surfaceContainerHighest,
                  foregroundColor: foreground ?? scheme.onSurface,
                  padding: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ),
        );

    Widget digit(String d) => key(
          Text(d, style: AppText.display(28)),
          () => onDigit(d),
          semantic: d,
        );

    Widget row(List<String> digits) =>
        Row(children: [for (final d in digits) digit(d)]);

    return Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          children: [
            key(
              const Icon(Icons.backspace_outlined),
              onBackspace,
              semantic: 'Borrar',
            ),
            digit('0'),
            key(
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Entrar'),
              ),
              onSubmit,
              semantic: 'Entrar',
              background: AppColors.esmeralda,
              foreground: AppColors.paper,
            ),
          ],
        ),
      ],
    );
  }
}
