import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'presentation/bindings/app_bindings.dart';
import 'presentation/controllers/theme_controller.dart';
import 'presentation/routes/app_pages.dart';
import 'presentation/routes/app_routes.dart';
import 'presentation/theme/app_theme.dart';

/// Punto de entrada de EyeSight AI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La cámara va a la altura del pecho en vertical (numeral 1.8).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  static const _locale = Locale('es', 'CO');
  static const _locales = [Locale('es', 'CO'), Locale('es')];

  @override
  Widget build(BuildContext context) {
    final error = startupError;
    if (error != null) {
      return MaterialApp(
        title: 'EyeSight AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: _StartupErrorView(message: error),
      );
    }
    final theme = Get.find<ThemeController>();
    return Obx(
      () => GetMaterialApp(
        title: 'EyeSight AI',
        debugShowCheckedModeBanner: false,
        locale: _locale,
        fallbackLocale: _locale,
        supportedLocales: _locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: theme.light,
        darkTheme: theme.dark,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      ),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
