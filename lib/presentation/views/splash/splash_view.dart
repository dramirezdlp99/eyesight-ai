import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/eye_logo.dart';
import '../../widgets/greca.dart';
import '../../widgets/motion.dart';

/// Bienvenida con el logotipo animado y la greca de la marca. Mientras se
/// muestra, decide a qué pantalla ir según el perfil guardado (HU01, CA5).
class SplashView extends StatefulWidget {
  const SplashView({
    super.key,
    required this.nextRoute,
    required this.navigate,
    this.minDuration = const Duration(milliseconds: 1800),
  });

  final Future<String> Function() nextRoute;
  final void Function(String route) navigate;
  final Duration minDuration;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    unawaited(_go());
  }

  Future<void> _go() async {
    final results = await Future.wait<Object>([
      widget.nextRoute(),
      Future<void>.delayed(widget.minDuration).then((_) => ''),
    ]);
    if (mounted) {
      widget.navigate(results.first as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadarRings(
                        color: AppColors.cobalt.withValues(alpha: 0.35),
                        size: 230,
                        child: const EyeLogo(size: 128),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: Text(
                          'EyeSight AI',
                          textAlign: TextAlign.center,
                          style: AppText.display(46, color: scheme.onSurface),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Ve los obstáculos por usted\n'
                        'y recuerda los lugares de riesgo',
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            color: AppColors.cobalt,
                            backgroundColor: scheme.surfaceContainerHighest,
                            value: reduceMotionOf(context) ? 0.6 : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preparando el modelo en su teléfono',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const GrecaBand(height: 56, animate: true),
        ],
      ),
    );
  }
}
