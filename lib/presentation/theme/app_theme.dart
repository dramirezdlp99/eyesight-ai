import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Familias tipográficas incluidas en `assets/fonts` (licencia OFL).
abstract final class AppFonts {
  /// Atkinson Hyperlegible Next: diseñada por el Braille Institute para
  /// personas con baja visión; distingue I, l y 1 u O y 0.
  static const String body = 'Atkinson';

  /// Bricolage Grotesque: títulos y cifras grandes.
  static const String display = 'Bricolage';
}

/// Estilos de título con la tipografía de la marca.
abstract final class AppText {
  static TextStyle display(double size, {Color? color}) => TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -size * 0.03,
        color: color,
      );
}

/// Temas «Barniz de Pasto»: claro, oscuro y alto contraste.
///
/// El texto base parte de 18 sp y los botones miden al menos 56 dp de alto,
/// por encima del mínimo de 48 dp (RNF07).
abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: AppColors.paper,
        surface: AppColors.paper,
        container: AppColors.mist,
        line: AppColors.line,
        primary: AppColors.cobalt,
        onPrimary: AppColors.paper,
        text: AppColors.ink,
        muted: AppColors.inkSoft,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: AppColors.night,
        surface: AppColors.night,
        container: AppColors.nightSurface,
        line: AppColors.nightLine,
        primary: AppColors.nightPrimary,
        onPrimary: AppColors.night,
        text: AppColors.nightText,
        muted: AppColors.nightMuted,
      );

  /// Perfil de baja visión: oro y blanco sobre negro, texto de 24 sp o más.
  static ThemeData highContrast() => _build(
        brightness: Brightness.dark,
        background: AppColors.contrastBackground,
        surface: AppColors.contrastBackground,
        container: AppColors.contrastSurface,
        line: AppColors.contrastText,
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
    required Color container,
    required Color line,
    required Color primary,
    required Color onPrimary,
    required Color text,
    required Color muted,
    double scale = 1,
    double borderWidth = 2,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: AppColors.oro,
      onSecondary: AppColors.ink,
      tertiary: AppColors.esmeralda,
      onTertiary: AppColors.paper,
      error: AppColors.carmin,
      onError: AppColors.paper,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerHighest: container,
      outline: line,
    );
    // Los estilos de Typography no traen tamaños; se combinan con la
    // geometría englishLike para poder escalar el texto (alto contraste).
    final typography = Typography.material2021();
    final base = typography.englishLike.merge(
      brightness == Brightness.light ? typography.black : typography.white,
    );
    TextStyle? title(TextStyle? s) => s?.copyWith(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        );
    final textTheme = base
        .copyWith(
          displayLarge: title(base.displayLarge),
          displayMedium: title(base.displayMedium),
          displaySmall: title(base.displaySmall),
          headlineLarge: title(base.headlineLarge),
          headlineMedium: title(base.headlineMedium),
          headlineSmall: title(base.headlineSmall),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 18),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 16),
          labelLarge: base.labelLarge
              ?.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
        )
        .apply(
          fontFamily: AppFonts.body,
          bodyColor: text,
          displayColor: text,
          fontSizeFactor: scale,
        );
    // apply() cambia la familia de todos los estilos; los títulos vuelven a
    // la tipografía de la marca.
    final themed = textTheme.copyWith(
      displayLarge: title(textTheme.displayLarge),
      displayMedium: title(textTheme.displayMedium),
      displaySmall: title(textTheme.displaySmall),
      headlineLarge: title(textTheme.headlineLarge),
      headlineMedium: title(textTheme.headlineMedium),
      headlineSmall: title(textTheme.headlineSmall),
    );

    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: background,
      textTheme: themed,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.display(24 * scale, color: text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: Size(64, 56 * scale),
          textStyle: themed.labelLarge,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: Size(64, 56 * scale),
          textStyle: themed.labelLarge,
          side: BorderSide(color: text, width: borderWidth),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
          textStyle: themed.titleMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: container,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
