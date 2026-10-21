import 'package:flutter/services.dart';

/// Tipo de uso con el que se pide la vibración a Android. Algunos teléfonos
/// bloquean ciertos tipos mientras la cámara está activa.
enum VibrationUsage {
  alarm('Alarma'),
  notification('Notificación'),
  accessibility('Accesibilidad'),
  touch('Táctil'),
  media('Multimedia');

  const VibrationUsage(this.label);

  final String label;
}

/// Vibración nativa por el canal `eyesight/vibrator` (MainActivity.kt).
class NativeVibrator {
  const NativeVibrator();

  static const MethodChannel _channel = MethodChannel('eyesight/vibrator');

  /// Devuelve `true` si Android aceptó la vibración.
  Future<bool> vibrate(List<int> pattern, VibrationUsage usage) async {
    final ok = await _channel.invokeMethod<bool>('vibrate', {
      'pattern': pattern,
      'usage': usage.name,
    });
    return ok ?? false;
  }
}
