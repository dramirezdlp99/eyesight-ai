import 'package:vibration/vibration.dart';

/// Retroalimentación háptica (RF08, HU04).
abstract interface class IHaptics {
  /// Patrón en milisegundos: espera, vibra, espera, vibra…
  Future<void> play(List<int> pattern);
}

class VibrationHaptics implements IHaptics {
  bool? _hasVibrator;
  bool? _hasAmplitude;

  /// Intensidad de cada tramo del patrón: 0 en las pausas y la máxima (255)
  /// en los pulsos, para que se sienta aunque el teléfono vibre suave.
  static List<int> intensities(List<int> pattern) =>
      [for (var i = 0; i < pattern.length; i++) i.isOdd ? 255 : 0];

  @override
  Future<void> play(List<int> pattern) async {
    _hasVibrator ??= await Vibration.hasVibrator();
    if (_hasVibrator != true || pattern.isEmpty) {
      return;
    }
    _hasAmplitude ??= await Vibration.hasAmplitudeControl();
    if (_hasAmplitude == true) {
      await Vibration.vibrate(
        pattern: pattern,
        intensities: intensities(pattern),
      );
    } else {
      await Vibration.vibrate(pattern: pattern);
    }
  }
}
