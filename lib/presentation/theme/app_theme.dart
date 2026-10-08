import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Temas de la aplicación: claro, oscuro y alto contraste (numeral 2.2.4).
///
/// Los tamaños de texto parten de 18 sp y los botones miden al menos 56 dp de
/// alto, por encima del mínimo de 48 dp (RNF07).
abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        primary: AppColors.lightPrimary,
        onPrimary: AppColors.lightOnPrimary,
        text: AppColors.lightText,
        muted: AppColors.lightMuted,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnPrimary,
        text: AppColors.darkText,
        muted: AppColors.darkMuted,
      );

  /// Perfil de baja visión: amarillo sobre negro y texto de al menos 24 sp.
  static ThemeData highContrast() => _build(
        brightness: Brightness.dark,
        background: AppColors.contrastBackground,
        surface: AppColors.contrastSurface,
        primary: AppColors.contrastPrimary,
        onPrimary: AppColors.contrastOnPrimary,
        text: AppColors.contrastText,
        muted: AppColors.contrastText,
        scale: 1.35,
        borderWidth: 3,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color onPrimary,
    required Color text,
    required Color muted,
    double scale = 1,
    double borderWidth = 1.5,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      error: AppColors.alertNear,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: muted,
    );
    // Los estilos black y white de Typography no traen tamaños; se combinan
    // con la geometría englishLike para poder escalar el texto (alto contraste).
    final typography = Typography.material2021();
    final base = typography.englishLike.merge(
      brightness == Brightness.light ? typography.black : typography.white,
    );
    final textTheme = base
        .copyWith(
          displaySmall:
              base.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          headlineMedium:
              base.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 18),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 16),
          labelLarge: base.labelLarge
              ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: text, displayColor: text, fontSizeFactor: scale);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: Size.fromHeight(56 * scale),
          textStyle: textTheme.labelLarge,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: Size.fromHeight(56 * scale),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: primary, width: borderWidth),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
