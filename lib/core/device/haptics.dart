import 'package:vibration/vibration.dart';

/// Retroalimentación háptica (RF08, HU04).
abstract interface class IHaptics {
  /// Patrón en milisegundos: espera, vibra, espera, vibra…
  Future<void> play(List<int> pattern);
}

/// Vibra con el patrón y la intensidad por defecto del teléfono.
///
/// No se fijan intensidades por tramo: en el vivo Y22s el teléfono decía
/// tener control de intensidad, pero con ese modo la vibración dejó de
/// sentirse. La intensidad por defecto sí funciona en todos los equipos.
class VibrationHaptics implements IHaptics {
  bool? _hasVibrator;

  @override
  Future<void> play(List<int> pattern) async {
    _hasVibrator ??= await Vibration.hasVibrator();
    if (_hasVibrator != true || pattern.isEmpty) {
      return;
    }
    await Vibration.vibrate(pattern: pattern);
  }
}
