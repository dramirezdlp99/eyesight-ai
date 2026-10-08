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
    expect(AppColors.contrast(AppColors.contrastPrimary, Colors.black),
        greaterThan(14));
  });

  test('cálculo de contraste: negro sobre blanco es 21:1', () {
    expect(AppColors.contrast(Colors.black, Colors.white), closeTo(21, 0.01));
  });
}
