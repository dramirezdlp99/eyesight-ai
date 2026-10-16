import 'package:flutter/material.dart';

import '../../domain/entities/proximity.dart';

/// Paleta «Barniz de Pasto».
///
/// Base blanca y sobria; cada color tiene un único significado, inspirado en
/// el barniz de Pasto (mopa-mopa) y en las grecas de Nariño:
///
/// * cobalto: la marca y las acciones;
/// * carmín: peligro cercano y zonas registradas automáticamente;
/// * oro: atención, avisos de zona y perfil de baja visión;
/// * esmeralda: acompañante, confirmaciones y zonas manuales.
///
/// Todos los pares de texto y fondo cumplen al menos 4,5:1 (RNF07,
/// WCAG 2.1); lo verifica `test/presentation/theme/app_theme_test.dart`.
abstract final class AppColors {
  // ---------------------------------------------------------------- Base
  static const Color paper = Color(0xFFFFFFFF);
  static const Color mist = Color(0xFFF3F4F8);
  static const Color line = Color(0xFFE3E4EA);
  static const Color ink = Color(0xFF17171C);
  static const Color inkSoft = Color(0xFF4B4B57);

  // ------------------------------------------------------------- Acentos
  static const Color cobalt = Color(0xFF2340D9);
  static const Color cobaltDeep = Color(0xFF1A2FA6);
  static const Color carmin = Color(0xFFD11F3A);
  static const Color carminDeep = Color(0xFFB0172F);
  static const Color oro = Color(0xFFF2B705);
  static const Color oroDeep = Color(0xFFD9A300);
  static const Color esmeralda = Color(0xFF00875A);
  static const Color esmeraldaDeep = Color(0xFF006B47);

  // -------------------------------------------------------------- Oscuro
  static const Color night = Color(0xFF121216);
  static const Color nightSurface = Color(0xFF1E1E25);
  static const Color nightLine = Color(0xFF34343F);
  static const Color nightText = Color(0xFFF4F4F6);
  static const Color nightMuted = Color(0xFFB9B9C4);
  static const Color nightPrimary = Color(0xFF9AACFF);

  // ----------------------------------------- Alto contraste (baja visión)
  static const Color contrastBackground = Color(0xFF000000);
  static const Color contrastSurface = Color(0xFF121212);
  static const Color contrastPrimary = oro;
  static const Color contrastOnPrimary = Color(0xFF000000);
  static const Color contrastText = Color(0xFFFFFFFF);

  // ------------------------------------------------------------ Cercanía
  /// Obstáculo cercano: 3 pulsos de vibración.
  static const Color alertNear = carmin;

  /// Obstáculo a media distancia: 2 pulsos.
  static const Color alertMedium = oro;

  /// Obstáculo lejano: 1 pulso.
  static const Color alertFar = Color(0xFF9A9AA6);

  static Color forProximity(Proximity proximity) => switch (proximity) {
        Proximity.near => alertNear,
        Proximity.medium => alertMedium,
        Proximity.far => alertFar,
      };

  /// Texto legible sobre el color de cada cercanía.
  static Color onProximity(Proximity proximity) => switch (proximity) {
        Proximity.near => paper,
        Proximity.medium => ink,
        Proximity.far => ink,
      };

  /// Relación de contraste WCAG entre dos colores (de 1 a 21).
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
