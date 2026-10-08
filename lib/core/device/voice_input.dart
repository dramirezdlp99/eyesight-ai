import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Reconocimiento de voz para perfiles, comandos y tipos de zona (RF13).
abstract interface class IVoiceInput {
  /// `true` si el teléfono tiene reconocimiento de voz disponible.
  Future<bool> init();

  /// Escucha una frase y devuelve el texto reconocido, o `null` si no se
  /// entendió nada antes de [timeout].
  Future<String?> listenOnce({Duration timeout = const Duration(seconds: 8)});

  Future<void> stop();
}

/// Implementación con speech_to_text. Prefiere el reconocimiento en el
/// teléfono cuando el paquete de idioma español está descargado.
class SpeechToTextVoiceInput implements IVoiceInput {
  SpeechToTextVoiceInput([SpeechToText? speech])
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _available = false;
  String? _localeId;

  @override
  Future<bool> init() async {
    if (_available) {
      return true;
    }
    try {
      _available = await _speech.initialize();
    } on Object {
      _available = false;
    }
    if (_available) {
      final locales = await _speech.locales();
      String? spanish;
      for (final l in locales) {
        final id = l.localeId.replaceAll('-', '_').toLowerCase();
        if (id == 'es_co') {
          spanish = l.localeId;
          break;
        }
        if (spanish == null && id.startsWith('es')) {
          spanish = l.localeId;
        }
      }
      _localeId = spanish;
    }
    return _available;
  }

  @override
  Future<String?> listenOnce(
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (!await init()) {
      return null;
    }
    final completer = Completer<String?>();
    var last = '';
    await _speech.listen(
      onResult: (result) {
        last = result.recognizedWords;
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(last.isEmpty ? null : last);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        cancelOnError: true,
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
      ),
    );
    final text = await completer.future.timeout(
      timeout + const Duration(seconds: 1),
      onTimeout: () => last.isEmpty ? null : last,
    );
    await _speech.stop();
    return text;
  }

  @override
  Future<void> stop() => _speech.stop();
}
