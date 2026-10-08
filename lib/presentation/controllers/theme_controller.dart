import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/user_profile.dart';
import '../theme/app_theme.dart';

/// Elige el tema según el perfil: el perfil de baja visión usa siempre el
/// tema de alto contraste (HU05); los demás siguen el modo claro u oscuro
/// del teléfono.
class ThemeController extends GetxController {
  final Rxn<UserProfile> profile = Rxn<UserProfile>();

  bool get highContrast => profile.value == UserProfile.lowVision;

  ThemeData get light =>
      highContrast ? AppTheme.highContrast() : AppTheme.light();

  ThemeData get dark =>
      highContrast ? AppTheme.highContrast() : AppTheme.dark();
}
