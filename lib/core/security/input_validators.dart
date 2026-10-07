import '../config/app_constants.dart';

/// Validación de todas las entradas del usuario (RNF12, control de
/// manipulación). Cada método devuelve `null` si el valor es válido o el
/// mensaje de error en español.
abstract final class InputValidators {
  static String? radius(double? value) {
    if (value == null ||
        value.isNaN ||
        value < AppConstants.minAlertRadiusM ||
        value > AppConstants.maxAlertRadiusM) {
      return 'El radio debe estar entre '
          '${AppConstants.minAlertRadiusM.toInt()} y '
          '${AppConstants.maxAlertRadiusM.toInt()} metros.';
    }
    return null;
  }

  static String? note(String value) {
    if (value.length > AppConstants.maxNoteLength) {
      return 'La nota admite máximo ${AppConstants.maxNoteLength} caracteres.';
    }
    return null;
  }

  static String? confidence(double? value) {
    if (value == null ||
        value.isNaN ||
        value < AppConstants.minConfidenceThreshold ||
        value > AppConstants.maxConfidenceThreshold) {
      return 'El umbral de confianza debe estar entre 0,30 y 0,90.';
    }
    return null;
  }

  static String? speechRate(double? value) {
    if (value == null ||
        value.isNaN ||
        value < AppConstants.minSpeechRate ||
        value > AppConstants.maxSpeechRate) {
      return 'La velocidad de la voz debe estar entre 0,5x y 2,0x.';
    }
    return null;
  }

  static String? pin(String value) {
    final valid = RegExp(
      '^[0-9]{${AppConstants.minPinLength},${AppConstants.maxPinLength}}\$',
    ).hasMatch(value);
    return valid
        ? null
        : 'El PIN debe tener entre ${AppConstants.minPinLength} y '
            '${AppConstants.maxPinLength} dígitos.';
  }

  static bool coordinates(double lat, double lng) =>
      !lat.isNaN &&
      !lng.isNaN &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;

  /// Recorta espacios, elimina caracteres de control y limita la longitud.
  static String sanitizeNote(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > AppConstants.maxNoteLength
        ? cleaned.substring(0, AppConstants.maxNoteLength)
        : cleaned;
  }

  /// Confirmación de borrado total: el usuario debe escribir «ELIMINAR»
  /// (HU14, CA2).
  static bool wipeConfirmation(String value) => value.trim() == 'ELIMINAR';
}
