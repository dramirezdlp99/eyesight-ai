import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/greca.dart';

/// Inicio del acompañante. Las pantallas de mapa, historial, ajustes,
/// privacidad y modo de pruebas se completan en el Bloque 4 (HU10 a HU15).
class CompanionHomeView extends StatelessWidget {
  const CompanionHomeView({super.key, required this.onChangeProfile});

  final VoidCallback onChangeProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
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
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acompañante',
                            style: text.titleMedium?.copyWith(
                              color: AppColors.paper,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            header: true,
                            child: Text(
                              'Gestión de EyeSight AI',
                              style: AppText.display(
                                34,
                                color: AppColors.paper,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mapa, historial, ajustes y privacidad llegan en el '
                  'Bloque 4.',
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Probar detección'),
                  onPressed: () => Get.toNamed<void>(AppRoutes.detectionTest),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Cambiar de perfil'),
                  onPressed: onChangeProfile,
                ),
              ],
            ),
          ),
          const GrecaBand(height: 40),
        ],
      ),
    );
  }
}
