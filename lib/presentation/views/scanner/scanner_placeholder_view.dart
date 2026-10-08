import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';

/// Lugar del escáner (HU02 a HU09), que llega en la segunda parte del
/// Bloque 3. Por ahora permite probar la detección y cambiar de perfil.
class ScannerPlaceholderView extends StatelessWidget {
  const ScannerPlaceholderView({super.key, required this.onChangeProfile});

  final VoidCallback onChangeProfile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Escáner')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
              'El escáner con voz y vibración llega en la parte 2 del Bloque 3.',
              style: text.titleLarge),
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
