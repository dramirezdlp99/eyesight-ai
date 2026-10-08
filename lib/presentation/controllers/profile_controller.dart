import 'package:get/get.dart';

import '../../core/device/speech_service.dart';
import '../../core/device/voice_input.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/usecases/voice_command_parser.dart';
import '../routes/app_routes.dart';
import 'theme_controller.dart';

enum ProfilePhase { idle, speaking, listening, done }

/// Selección del perfil por voz o con botones (HU01, RF01).
class ProfileController extends GetxController {
  ProfileController({
    required ISpeechService speech,
    required IVoiceInput voice,
    required ISettingsRepository settings,
    required void Function(String route) navigate,
    ThemeController? theme,
    this.autoStart = true,
  })  : _speech = speech,
        _voice = voice,
        _settings = settings,
        _navigate = navigate,
        _theme = theme;

  final ISpeechService _speech;
  final IVoiceInput _voice;
  final ISettingsRepository _settings;
  final void Function(String route) _navigate;
  final ThemeController? _theme;
  final bool autoStart;

  static const String welcome =
      'Te damos la bienvenida a EyeSight AI. Di: ceguera total, baja visión o '
      'acompañante. También puedes tocar uno de los tres botones.';
  static const String retry =
      'No entendí. Di: ceguera total, baja visión o acompañante.';
  static const String fallback =
      'No entendí. Puedes elegir tu perfil con los botones de la pantalla.';

  /// Intentos de voz antes de pasar a los botones (HU01, CA4).
  static const int maxVoiceAttempts = 2;

  final Rx<ProfilePhase> phase = ProfilePhase.idle.obs;
  final RxnString heard = RxnString();
  int failures = 0;
  bool _selected = false;

  @override
  void onReady() {
    super.onReady();
    if (autoStart) {
      start();
    }
  }

  /// CA1: anuncia los perfiles y escucha.
  Future<void> start() async {
    phase.value = ProfilePhase.speaking;
    await _speech.speak(welcome);
    await listenForProfile();
  }

  Future<void> listenForProfile() async {
    while (!_selected && !isClosed && failures < maxVoiceAttempts) {
      phase.value = ProfilePhase.listening;
      final text = await _voice.listenOnce();
      if (_selected || isClosed) {
        return;
      }
      heard.value = text;
      final profile =
          text == null ? null : VoiceCommandParser.parseProfile(text);
      if (profile != null) {
        await select(profile);
        return;
      }
      failures++;
      if (failures < maxVoiceAttempts) {
        phase.value = ProfilePhase.speaking;
        await _speech.speak(retry);
      }
    }
    if (!_selected && !isClosed) {
      phase.value = ProfilePhase.idle;
      await _speech.speak(fallback);
    }
  }

  /// CA2 y CA3: guarda el perfil de usuario final o pasa al PIN.
  Future<void> select(UserProfile profile) async {
    if (_selected) {
      return;
    }
    _selected = true;
    phase.value = ProfilePhase.done;
    await _voice.stop();
    if (profile == UserProfile.companion) {
      await _speech.speak('Perfil acompañante. Ingresa el PIN.');
      _navigate(AppRoutes.pin);
      return;
    }
    final current = await _settings.load();
    await _settings.save(current.copyWith(profile: profile));
    _theme?.profile.value = profile;
    await _speech.speak('Perfil ${profile.spokenName} seleccionado.');
    _navigate(AppRoutes.scanner);
  }
}
