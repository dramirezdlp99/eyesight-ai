import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/presentation/theme/app_colors.dart';
import 'package:eyesight_ai/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contraste mínimo de 4,5:1 (RNF07, WCAG 2.1)', () {
    final themes = {
      'claro': AppTheme.light(),
      'oscuro': AppTheme.dark(),
      'alto contraste': AppTheme.highContrast(),
    };
    for (final entry in themes.entries) {
      test(entry.key, () {
        final t = entry.value;
        final s = t.colorScheme;
        expect(AppColors.contrast(s.onSurface, s.surface),
            greaterThanOrEqualTo(4.5));
        expect(AppColors.contrast(s.onSurface, t.scaffoldBackgroundColor),
            greaterThanOrEqualTo(4.5));
        expect(AppColors.contrast(s.onSurfaceVariant, s.surface),
            greaterThanOrEqualTo(4.5));
        expect(AppColors.contrast(s.onPrimary, s.primary),
            greaterThanOrEqualTo(4.5));
        expect(AppColors.contrast(s.primary, t.scaffoldBackgroundColor),
            greaterThanOrEqualTo(3));
      });
    }
  });

  test('alto contraste: amarillo sobre negro y texto de al menos 24 sp (HU05)',
      () {
    final t = AppTheme.highContrast();
    expect(t.colorScheme.primary, AppColors.contrastPrimary);
    expect(t.scaffoldBackgroundColor, Colors.black);
    expect(t.textTheme.bodyLarge!.fontSize, greaterThanOrEqualTo(24));
    // Oro sobre negro: 11,5:1, por encima del nivel AAA (7:1).
    expect(AppColors.contrast(AppColors.contrastPrimary, Colors.black),
        greaterThan(7));
  });

  test('el texto de cada tarjeta de cercanía se lee bien (HU03, HU04)', () {
    for (final p in Proximity.values) {
      expect(
        AppColors.contrast(AppColors.onProximity(p), AppColors.forProximity(p)),
        greaterThanOrEqualTo(4.5),
        reason: p.name,
      );
    }
  });

  test('pares de la paleta Barniz de Pasto con 4,5:1 o más', () {
    const pairs = [
      (AppColors.paper, AppColors.cobalt),
      (AppColors.paper, AppColors.carmin),
      (AppColors.paper, AppColors.esmeralda),
      (AppColors.ink, AppColors.oro),
      (AppColors.oro, AppColors.ink),
      (AppColors.ink, AppColors.mist),
      (AppColors.inkSoft, AppColors.mist),
      (AppColors.nightText, AppColors.nightSurface),
      (AppColors.carmin, AppColors.paper),
    ];
    for (final (fg, bg) in pairs) {
      expect(AppColors.contrast(fg, bg), greaterThanOrEqualTo(4.5),
          reason: '$fg sobre $bg');
    }
  });

  test('títulos con la tipografía de la marca y texto con Atkinson', () {
    final t = AppTheme.light();
    expect(t.textTheme.headlineMedium!.fontFamily, AppFonts.display);
    expect(t.textTheme.bodyLarge!.fontFamily, AppFonts.body);
    expect(AppText.display(40).fontWeight, FontWeight.w800);
  });

  test('cálculo de contraste: negro sobre blanco es 21:1', () {
    expect(AppColors.contrast(Colors.black, Colors.white), closeTo(21, 0.01));
  });
}
