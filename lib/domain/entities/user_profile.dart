/// Perfiles de uso de EyeSight AI (numeral 4.1.4, RF01).
enum UserProfile {
  /// Persona con ceguera total: voz, gestos y vibración.
  totalBlindness('ceguera total'),

  /// Persona con baja visión: además, vista de alto contraste.
  lowVision('baja visión'),

  /// Acompañante: administrador local protegido con PIN.
  companion('acompañante');

  const UserProfile(this.spokenName);

  /// Nombre que se anuncia por voz.
  final String spokenName;

  /// Los perfiles de usuario final abren el escáner (RF03).
  bool get isEndUser => this != UserProfile.companion;

  /// Convierte el nombre guardado en Hive al perfil, o `null` si no existe.
  static UserProfile? fromName(String? name) {
    for (final profile in UserProfile.values) {
      if (profile.name == name) {
        return profile;
      }
    }
    return null;
  }
}
