import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';

/// Inicio del acompañante. Las pantallas de mapa, historial, ajustes,
/// privacidad y modo de pruebas se completan en el Bloque 4 (HU10 a HU15).
class CompanionHomeView extends StatelessWidget {
  const CompanionHomeView({super.key, required this.onChangeProfile});

  final VoidCallback onChangeProfile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Acompañante')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Gestión de EyeSight AI', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Mapa, historial, ajustes y privacidad llegan en el Bloque 4.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Probar detección'),
            onPressed: () => Get.toNamed<void>(AppRoutes.detectionTest),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Cambiar de perfil'),
            onPressed: onChangeProfile,
          ),
        ],
      ),
    );
  }
}
