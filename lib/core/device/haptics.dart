import 'package:vibration/vibration.dart';

/// Retroalimentación háptica (RF08, HU04).
abstract interface class IHaptics {
  /// Patrón en milisegundos: espera, vibra, espera, vibra…
  Future<void> play(List<int> pattern);
}

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
