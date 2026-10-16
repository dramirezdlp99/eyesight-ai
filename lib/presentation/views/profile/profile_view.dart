import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/entities/user_profile.dart';
import '../../controllers/profile_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/eye_logo.dart';
import '../../widgets/greca.dart';
import '../../widgets/motion.dart';

/// Selección de perfil (HU01, diseño «Barniz de Pasto»).
///
/// Tres tarjetas de color: cobalto para ceguera total, negro con oro para
/// baja visión y esmeralda para el acompañante.
class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const EyeLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'EyeSight AI',
                      style: AppText.display(22, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  '¿Cómo usará la aplicación?',
                  style: AppText.display(34, color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 14),
              Obx(
                () => _ListeningChip(
                  phase: controller.phase.value,
                  heard: controller.heard.value,
                ),
              ),
              const SizedBox(height: 20),
              StaggeredEntrance(
                gap: 12,
                children: [
                  _ProfileCard(
                    profile: UserProfile.totalBlindness,
                    onTap: () => controller.select(UserProfile.totalBlindness),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ProfileCard(
                            profile: UserProfile.lowVision,
                            compact: true,
                            onTap: () =>
                                controller.select(UserProfile.lowVision),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProfileCard(
                            profile: UserProfile.companion,
                            compact: true,
                            onTap: () =>
                                controller.select(UserProfile.companion),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El perfil se recuerda en este teléfono',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indica si la app habla, escucha o espera un toque.
class _ListeningChip extends StatelessWidget {
  const _ListeningChip({required this.phase, required this.heard});

  final ProfilePhase phase;
  final String? heard;

  static String status(ProfilePhase phase, String? heard) => switch (phase) {
        ProfilePhase.listening => 'Le escucho.',
        ProfilePhase.speaking =>
          heard == null ? 'Le hablo…' : 'Escuché: «$heard»',
        ProfilePhase.idle => 'Elija su perfil con los botones.',
        ProfilePhase.done => 'Perfil elegido.',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final listening = phase == ProfilePhase.listening;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 28,
            child: Center(
              child: listening
                  ? WaveBars(color: scheme.primary, height: 26)
                  : Icon(Icons.mic_none, color: scheme.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status(phase, heard), style: text.titleMedium),
                  Text(
                    'Diga su perfil o toque una opción.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onTap,
    this.compact = false,
  });

  final UserProfile profile;
  final VoidCallback onTap;
  final bool compact;

  static String title(UserProfile p) => switch (p) {
        UserProfile.totalBlindness => 'Ceguera total',
        UserProfile.lowVision => 'Baja visión',
        UserProfile.companion => 'Acompañante',
      };

  static String hint(UserProfile p) => switch (p) {
        UserProfile.totalBlindness => 'Le guío con voz, vibración y gestos',
        UserProfile.lowVision => 'Letra grande y alto contraste',
        UserProfile.companion => 'Zonas y ajustes, con PIN',
      };

  static IconData icon(UserProfile p) => switch (p) {
        UserProfile.totalBlindness => Icons.record_voice_over,
        UserProfile.lowVision => Icons.contrast,
        UserProfile.companion => Icons.supervisor_account,
      };

  /// Fondo, texto y acento de la greca de cada perfil.
  static (Color, Color, Color, Color) colors(UserProfile p) => switch (p) {
        UserProfile.totalBlindness => (
            AppColors.cobalt,
            AppColors.paper,
            AppColors.cobaltDeep,
            AppColors.oro,
          ),
        UserProfile.lowVision => (
            AppColors.ink,
            AppColors.oro,
            AppColors.inkSoft,
            AppColors.oro,
          ),
        UserProfile.companion => (
            AppColors.esmeralda,
            AppColors.paper,
            AppColors.esmeraldaDeep,
            AppColors.paper,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (background, foreground, step, accent) = colors(profile);
    return Semantics(
      button: true,
      label: '${title(profile)}. ${hint(profile)}',
      onTap: onTap,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 168 : 150),
        child: Material(
          color: background,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: GrecaCorner(
                    color: step,
                    accent: accent,
                    width: compact ? 70 : 130,
                    height: compact ? 52 : 92,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon(profile), size: 34, color: foreground),
                      SizedBox(height: compact ? 22 : 18),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title(profile),
                          style: AppText.display(
                            compact ? 26 : 32,
                            color: foreground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hint(profile),
                        style: text.bodyMedium?.copyWith(color: foreground),
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
