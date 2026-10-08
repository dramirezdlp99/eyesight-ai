import 'package:get/get.dart';

import '../../core/config/app_constants.dart';
import '../../core/device/speech_service.dart';
import '../../core/security/input_validators.dart';
import '../../core/security/pin_guard.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../routes/app_routes.dart';
import 'theme_controller.dart';

enum PinMode { create, confirm, verify }

/// PIN del acompañante: creación la primera vez y verificación después
/// (HU01 CA3, RF02, RNF10).
class PinController extends GetxController {
  PinController({
    required PinGuard guard,
    required ISettingsRepository settings,
    required ISpeechService speech,
    required void Function(String route) navigate,
    ThemeController? theme,
  })  : _guard = guard,
        _settings = settings,
        _speech = speech,
        _navigate = navigate,
        _theme = theme;

  final PinGuard _guard;
  final ISettingsRepository _settings;
  final ISpeechService _speech;
  final void Function(String route) _navigate;
  final ThemeController? _theme;

  final Rx<PinMode> mode = PinMode.verify.obs;
  final RxString entered = ''.obs;
  final RxnString error = RxnString();
  final RxBool busy = false.obs;
  String _first = '';

  String get title => switch (mode.value) {
        PinMode.create => 'Crea un PIN de 4 a 6 dígitos',
        PinMode.confirm => 'Repite el PIN',
        PinMode.verify => 'Ingresa el PIN',
      };

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    mode.value = await _guard.hasPin() ? PinMode.verify : PinMode.create;
  }

  void addDigit(String digit) {
    if (entered.value.length >= AppConstants.maxPinLength) {
      return;
    }
    error.value = null;
    entered.value += digit;
  }

  void backspace() {
    final v = entered.value;
    if (v.isNotEmpty) {
      entered.value = v.substring(0, v.length - 1);
    }
  }

  Future<void> submit() async {
    if (busy.value) {
      return;
    }
    busy.value = true;
    final pin = entered.value;
    entered.value = '';
    try {
      switch (mode.value) {
        case PinMode.create:
          final invalid = InputValidators.pin(pin);
          if (invalid != null) {
            error.value = invalid;
            return;
          }
          _first = pin;
          mode.value = PinMode.confirm;
          await _speech.speak('Repite el PIN.');
        case PinMode.confirm:
          if (pin != _first) {
            _first = '';
            mode.value = PinMode.create;
            error.value = 'Los PIN no coinciden. Créalo de nuevo.';
            return;
          }
          await _guard.setPin(pin);
          await _enter();
        case PinMode.verify:
          final result = await _guard.verify(pin);
          switch (result) {
            case PinAccepted():
              await _enter();
            case PinRejected(:final remainingAttempts):
              error.value =
                  'PIN incorrecto. Quedan $remainingAttempts intentos.';
            case PinLocked(:final remaining):
              error.value =
                  'Demasiados intentos. Espera ${remaining.inSeconds} segundos.';
            case PinNotSet():
              mode.value = PinMode.create;
          }
      }
    } finally {
      busy.value = false;
    }
  }

  /// Vuelve a la selección de perfil sin entrar (botón «Cambiar de perfil»).
  Future<void> changeProfile() async {
    final current = await _settings.load();
    await _settings.save(current.copyWith(clearProfile: true));
    _theme?.profile.value = null;
    _navigate(AppRoutes.profile);
  }

  Future<void> _enter() async {
    final current = await _settings.load();
    await _settings.save(current.copyWith(profile: UserProfile.companion));
    _theme?.profile.value = UserProfile.companion;
    await _speech.speak('Hola, acompañante.');
    _navigate(AppRoutes.companion);
  }
}
