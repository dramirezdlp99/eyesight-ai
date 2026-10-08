import 'package:flutter_tts/flutter_tts.dart';

/// Síntesis de voz (RF07, numeral 2.5.5).
abstract interface class ISpeechService {
  Future<void> init();

  /// [rate] es el multiplicador de los ajustes (1,0 = normal).
  Future<void> configure({required double rate, required double volume});

  /// Habla [text]. Con [interrupt] corta lo que se esté diciendo, para que
  /// la alerta más reciente se escuche de inmediato.
  Future<void> speak(String text, {bool interrupt = true});

  Future<void> stop();
}

/// Implementación con el motor de voz del teléfono (flutter_tts), sin
/// conexión a internet.
class FlutterTtsSpeechService implements ISpeechService {
  FlutterTtsSpeechService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  /// Idiomas en orden de preferencia: español de Colombia y, si el teléfono
  /// no lo tiene, otras variantes de español.
  static const List<String> languages = ['es-CO', 'es-US', 'es-MX', 'es-ES'];

  @override
  Future<void> init() async {
    if (_ready) {
      return;
    }
    for (final lang in languages) {
      final available = await _tts.isLanguageAvailable(lang);
      if (available is bool && available) {
        await _tts.setLanguage(lang);
        break;
      }
    }
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  /// El motor de Android usa 0,5 como velocidad normal.
  static double engineRate(double multiplier) {
    final rate = 0.5 * multiplier;
    if (rate < 0.1) {
      return 0.1;
    }
    return rate > 1.0 ? 1.0 : rate;
  }

  @override
  Future<void> configure({required double rate, required double volume}) async {
    await init();
    await _tts.setSpeechRate(engineRate(rate));
    await _tts.setVolume(volume);
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    await init();
    if (interrupt) {
      await _tts.stop();
    }
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
