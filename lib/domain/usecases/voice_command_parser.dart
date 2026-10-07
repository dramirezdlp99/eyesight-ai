import '../entities/user_profile.dart';

/// Comandos de voz del escáner (RF13).
enum VoiceCommand { repeat, mute, markZone, terminate, cancel, yes, no }

/// Interpreta el texto reconocido por el servicio de voz.
///
/// Normaliza mayúsculas, tildes y signos, y compara palabras completas, para
/// que «sí» no se confunda con «silencio» (HU09, CA4: un comando no
/// reconocido no ejecuta ninguna acción).
abstract final class VoiceCommandParser {
  static const Map<VoiceCommand, List<String>> _commands = {
    VoiceCommand.markZone: ['marcar zona', 'marca zona', 'marcar la zona'],
    VoiceCommand.repeat: ['repetir', 'repite', 'repita', 'otra vez'],
    VoiceCommand.mute: ['silencio', 'silenciar', 'silencia'],
    VoiceCommand.terminate: ['terminar', 'termina', 'detener', 'finalizar'],
    VoiceCommand.cancel: ['cancelar', 'cancela'],
    VoiceCommand.yes: ['si', 'confirmo', 'confirmar'],
    VoiceCommand.no: ['no'],
  };

  static const Map<UserProfile, List<String>> _profiles = {
    UserProfile.totalBlindness: ['ceguera total', 'ceguera', 'ciego', 'ciega'],
    UserProfile.lowVision: ['baja vision', 'vision baja', 'baja'],
    UserProfile.companion: ['acompanante', 'acompanar'],
  };

  static const Map<String, List<String>> _zoneTypes = {
    'pothole': ['hueco', 'huecos', 'bache', 'hoyo'],
    'step': ['escalon', 'escalones', 'grada', 'gradas', 'anden', 'borde'],
    'construction': ['obra', 'obras', 'construccion'],
    'other': ['otro', 'otra', 'otros'],
  };

  /// Minúsculas, sin tildes ni signos y con espacios simples.
  static String normalize(String text) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      if (i >= 0) {
        buffer.write(to[i]);
      } else if (RegExp('[a-z0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static VoiceCommand? parseCommand(String text) =>
      _firstMatch(_commands, normalize(text));

  static UserProfile? parseProfile(String text) =>
      _firstMatch(_profiles, normalize(text));

  /// Tipo de zona manual dictado: `pothole`, `step`, `construction` u `other`.
  static String? parseZoneType(String text) =>
      _firstMatch(_zoneTypes, normalize(text));

  static T? _firstMatch<T>(Map<T, List<String>> table, String normalized) {
    if (normalized.isEmpty) {
      return null;
    }
    final padded = ' $normalized ';
    for (final entry in table.entries) {
      for (final phrase in entry.value) {
        if (padded.contains(' $phrase ')) {
          return entry.key;
        }
      }
    }
    return null;
  }
}
