import 'package:flutter/services.dart';

import '../../domain/entities/proximity.dart';

/// Pitido de una alerta: frecuencia, duración y pausa posterior.
typedef Tone = (int hz, int ms, int gapMs);

/// Pitidos suaves de las alertas (respaldo de la vibración, HU04).
///
/// Repiten el código de la vibración: 3 pitidos si el obstáculo está cerca,
/// 2 a media distancia, 1 lejos y un tono doble descendente para las zonas.
/// Son ondas seno cortas, más agudas cuanto más cerca, para que avisen sin
/// molestar. Algunos teléfonos (como el vivo Y22s) bloquean la vibración
/// mientras la cámara está activa; el sonido no se bloquea.
abstract final class Earcons {
  static const List<Tone> near = [(988, 70, 70), (988, 70, 70), (988, 70, 0)];
  static const List<Tone> medium = [(784, 80, 90), (784, 80, 0)];
  static const List<Tone> far = [(659, 90, 0)];
  static const List<Tone> zone = [(784, 140, 30), (523, 220, 0)];

  static List<Tone> forProximity(Proximity proximity) => switch (proximity) {
        Proximity.near => near,
        Proximity.medium => medium,
        Proximity.far => far,
      };
}

abstract interface class IEarcons {
  Future<void> play(List<Tone> tones);
}

/// Reproduce los pitidos con el canal nativo `eyesight/tones`
/// (MainActivity.kt), sin plugins adicionales.
class NativeEarcons implements IEarcons {
  const NativeEarcons({this.volume = 0.35});

  static const MethodChannel _channel = MethodChannel('eyesight/tones');

  /// Volumen relativo (0 a 1) respecto al volumen multimedia del teléfono.
  final double volume;

  @override
  Future<void> play(List<Tone> tones) async {
    if (tones.isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('play', {
        'tones': [
          for (final (hz, ms, gap) in tones) [hz, ms, gap],
        ],
        'volume': volume,
      });
    } on Object {
      // Sin pitidos quedan la voz y la vibración (RNF05).
    }
  }
}
