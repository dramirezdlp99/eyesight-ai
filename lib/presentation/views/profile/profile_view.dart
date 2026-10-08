import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/entities/user_profile.dart';
import '../../controllers/profile_controller.dart';
import '../../widgets/eye_logo.dart';

/// Selección de perfil (wireframe de la HU01, figura a).
class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Center(child: EyeLogo(size: 110)),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                'EyeSight AI',
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Cómo vas a usar la aplicación?',
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Di tu perfil en voz alta o toca un botón.',
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            const SizedBox(height: 32),
            for (final p in UserProfile.values) ...[
              _ProfileButton(profile: p, onTap: () => controller.select(p)),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            Obx(
              () => Semantics(
                liveRegion: true,
                child: Text(
                  _status(controller.phase.value, controller.heard.value),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _status(ProfilePhase phase, String? heard) => switch (phase) {
        ProfilePhase.listening => 'Escuchando…',
        ProfilePhase.speaking =>
          heard == null ? 'Hablando…' : 'Escuché: «$heard»',
        ProfilePhase.idle => 'Elige tu perfil con los botones.',
        ProfilePhase.done => '',
      };
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  static String title(UserProfile p) => switch (p) {
        UserProfile.totalBlindness => 'Ceguera total',
        UserProfile.lowVision => 'Baja visión',
        UserProfile.companion => 'Acompañante',
      };

  static String hint(UserProfile p) => switch (p) {
        UserProfile.totalBlindness => 'Alertas por voz y vibración',
        UserProfile.lowVision => 'Además, pantalla de alto contraste',
        UserProfile.companion => 'Configura y gestiona las zonas, con PIN',
      };

  static IconData icon(UserProfile p) => switch (p) {
        UserProfile.totalBlindness => Icons.record_voice_over,
        UserProfile.lowVision => Icons.contrast,
        UserProfile.companion => Icons.supervisor_account,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${title(profile)}. ${hint(profile)}',
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.primary, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Icon(icon(profile), size: 40, color: scheme.primary),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title(profile), style: text.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        hint(profile),
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
