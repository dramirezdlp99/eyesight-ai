import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Punto de entrada de EyeSight AI.
///
/// Bloque 0: núcleo y dominio. La interfaz completa (perfiles, escáner,
/// zonas y pantallas del acompañante) se incorpora en los bloques siguientes.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EyeSightApp());
}

class EyeSightApp extends StatelessWidget {
  const EyeSightApp({super.key});

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
      home: const _BlockZeroScreen(),
    );
  }
}

class _BlockZeroScreen extends StatelessWidget {
  const _BlockZeroScreen();

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
                  'Bloque 0: núcleo y dominio verificados con pruebas.',
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
