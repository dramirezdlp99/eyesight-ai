import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/eye_logo.dart';

/// Pantalla de inicio con el logotipo animado. Mientras se muestra, decide
/// a qué pantalla ir según el perfil guardado (HU01, CA5).
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EyeLogo(size: 180),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text('EyeSight AI', style: text.displaySmall),
              ),
              const SizedBox(height: 8),
              Text(
                'Percibe tu camino',
                style: text.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
