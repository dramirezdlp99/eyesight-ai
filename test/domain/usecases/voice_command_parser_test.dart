import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/domain/usecases/history_retention.dart';
import 'package:eyesight_ai/domain/usecases/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  group('normalización', () {
    test('quita tildes, mayúsculas y signos', () {
      expect(VoiceCommandParser.normalize('¡Baja VISIÓN!'), 'baja vision');
      expect(VoiceCommandParser.normalize('  Acompañante.  '), 'acompanante');
    });
  });

  group('comandos del escáner (RF13)', () {
    final cases = {
      'repetir': VoiceCommand.repeat,
      'Repite por favor': VoiceCommand.repeat,
      'silencio': VoiceCommand.mute,
      'Marcar zona': VoiceCommand.markZone,
      'marca zona aquí': VoiceCommand.markZone,
      'terminar': VoiceCommand.terminate,
      'cancelar': VoiceCommand.cancel,
      'sí': VoiceCommand.yes,
      'no': VoiceCommand.no,
    };
    for (final entry in cases.entries) {
      test('«${entry.key}»', () {
        expect(VoiceCommandParser.parseCommand(entry.key), entry.value);
      });
    }

    test('«silencio» no se confunde con «sí»', () {
      expect(VoiceCommandParser.parseCommand('silencio'), VoiceCommand.mute);
    });

    test('un texto no reconocido no ejecuta nada (HU09, CA4)', () {
      expect(VoiceCommandParser.parseCommand('buenos días'), isNull);
      expect(VoiceCommandParser.parseCommand(''), isNull);
    });
  });

  group('perfiles (HU01, CA2)', () {
    test('reconoce los tres perfiles', () {
      expect(VoiceCommandParser.parseProfile('Ceguera total'),
          UserProfile.totalBlindness);
      expect(VoiceCommandParser.parseProfile('baja visión'),
          UserProfile.lowVision);
      expect(VoiceCommandParser.parseProfile('acompañante'),
          UserProfile.companion);
      expect(VoiceCommandParser.parseProfile('hola'), isNull);
    });
  });

  group('tipos de zona manual (HU07, CA2)', () {
    test('reconoce hueco, escalón, obra y otro', () {
      expect(VoiceCommandParser.parseZoneType('un hueco'), 'pothole');
      expect(VoiceCommandParser.parseZoneType('Escalón'), 'step');
      expect(VoiceCommandParser.parseZoneType('obra'), 'construction');
      expect(VoiceCommandParser.parseZoneType('otro'), 'other');
      expect(VoiceCommandParser.parseZoneType('perro'), isNull);
    });
  });

  test('retención del historial: 90 días (HU12, CA4)', () {
    expect(HistoryRetention.cutoff(t0), t0.subtract(const Duration(days: 90)));
  });
}
