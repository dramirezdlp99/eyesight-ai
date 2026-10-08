import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'presentation/bindings/app_bindings.dart';

/// Punto de entrada de EyeSight AI.
///
/// Bloque 1: abre el almacenamiento cifrado y registra las dependencias.
/// La interfaz completa llega en los bloques 3 y 4.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await AppBindings.init();
  } on Object catch (e) {
    startupError = 'No se pudo abrir el almacenamiento cifrado: $e';
  }
  runApp(EyeSightApp(startupError: startupError));
}

class EyeSightApp extends StatelessWidget {
  const EyeSightApp({super.key, this.startupError});

  /// Mensaje si falló el arranque; la app lo muestra en lugar de cerrarse.
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EyeSight AI',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B3A5C)),
      ),
      home: _StatusScreen(error: startupError),
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text('EyeSight AI', style: text.headlineLarge),
                ),
                const SizedBox(height: 16),
                Text(
                  error ??
                      'Bloque 1: almacenamiento cifrado y seguridad listos.',
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
