import 'package:eyesight_ai/core/config/app_constants.dart';
import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterTtsSpeechService.engineRate (HU13, CA2)', () {
    test('1,0x equivale a la velocidad normal del motor de Android (0,5)', () {
      expect(FlutterTtsSpeechService.engineRate(1.0), 0.5);
    });

    test('el rango de los ajustes (0,5x a 2,0x) cabe en el motor', () {
      expect(
        FlutterTtsSpeechService.engineRate(AppConstants.minSpeechRate),
        0.25,
      );
      expect(
        FlutterTtsSpeechService.engineRate(AppConstants.maxSpeechRate),
        1.0,
      );
    });

    test('valores fuera de rango se acotan entre 0,1 y 1,0', () {
      expect(FlutterTtsSpeechService.engineRate(0), 0.1);
      expect(FlutterTtsSpeechService.engineRate(5), 1.0);
    });

    test('prefiere el español de Colombia', () {
      expect(FlutterTtsSpeechService.languages.first, 'es-CO');
    });
  });

  test('cada permiso explica para qué se usa (HU02, CA2)', () {
    for (final p in AppPermission.values) {
      expect(p.reason, isNotEmpty);
    }
    expect(AppPermission.values, hasLength(3));
  });
}
