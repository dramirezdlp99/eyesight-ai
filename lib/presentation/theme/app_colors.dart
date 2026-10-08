import 'package:flutter/material.dart';

/// Paleta de EyeSight AI: identidad propia, sin elementos de terceros.
///
/// Azul profundo como color principal, ámbar reservado para las alertas y un
/// modo de alto contraste (amarillo sobre negro) para el perfil de baja
/// visión. Cada par de texto y fondo cumple al menos 4,5:1 (RNF07, WCAG 2.1).
abstract final class AppColors {
  // ---------------------------------------------------------------- Claro
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1A4B8C);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF14202E);
  static const Color lightMuted = Color(0xFF4A5868);

  // ---------------------------------------------------------------- Oscuro
  static const Color darkBackground = Color(0xFF0D141F);
  static const Color darkSurface = Color(0xFF162131);
  static const Color darkPrimary = Color(0xFF8DB9FF);
  static const Color darkOnPrimary = Color(0xFF0A1A30);
  static const Color darkText = Color(0xFFE8EEF6);
  static const Color darkMuted = Color(0xFFA9B6C6);

  // ------------------------------------------------- Alto contraste (BV)
  static const Color contrastBackground = Color(0xFF000000);
  static const Color contrastSurface = Color(0xFF121212);
  static const Color contrastPrimary = Color(0xFFFFD600);
  static const Color contrastOnPrimary = Color(0xFF000000);
  static const Color contrastText = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------- Alertas
  /// Obstáculo cercano.
  static const Color alertNear = Color(0xFFE53935);

  /// Obstáculo a media distancia.
  static const Color alertMedium = Color(0xFFFFB300);

  /// Obstáculo lejano.
  static const Color alertFar = Color(0xFFB0BEC5);

  /// Relación de contraste WCAG entre dos colores (de 1 a 21).
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
