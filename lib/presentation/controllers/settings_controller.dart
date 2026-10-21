import 'package:get/get.dart';

import '../../core/config/app_constants.dart';
import '../../core/device/haptics.dart';
import '../../core/device/speech_service.dart';
import '../../core/device/video_source_selector.dart';
import '../../core/security/input_validators.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/video_source_kind.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/usecases/alert_policy.dart';

/// Ajustes de la herramienta (HU13, RF18, RF19; diagrama de clases:
/// SettingsController). Cada cambio válido se guarda de inmediato.
class SettingsController extends GetxController {
  SettingsController({
    required ISettingsRepository settings,
    required ISpeechService speech,
    required VideoSourceSelector sources,
    IHaptics? haptics,
  })  : _settings = settings,
        _speech = speech,
        _sources = sources,
        _haptics = haptics;

  final ISettingsRepository _settings;
  final ISpeechService _speech;
  final VideoSourceSelector _sources;
  final IHaptics? _haptics;

  /// Frase de ejemplo al cambiar la voz (HU13, CA1).
  static const String sample =
      'Así sonarán las alertas: poste, cerca, al frente.';
  static const String usbMissing =
      'No hay una cámara USB conectada. Se mantiene la cámara del teléfono.';
  static const String resetDone = 'Se restablecieron los valores por defecto.';
  static const String vibrationTest =
      'Debió sentir 3 pulsos, como un obstáculo cercano. Si no los sintió, '
      'revise la vibración de alarmas en los ajustes del teléfono.';

  final Rx<AppSettings> value = const AppSettings().obs;

  /// Mensaje para el acompañante (error o confirmación).
  final RxnString message = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async => value.value = await _settings.load();

  Future<void> _save(AppSettings next) async {
    value.value = next;
    await _settings.save(next);
  }

  /// Velocidad y volumen: se guardan y se reproduce la frase de ejemplo
  /// (HU13, CA1). Se llama al soltar el control deslizante.
  Future<void> setVoice({double? rate, double? volume}) async {
    if (rate != null) {
      final error = InputValidators.speechRate(rate);
      if (error != null) {
        message.value = error;
        return;
      }
    }
    if (volume != null && (volume.isNaN || volume < 0 || volume > 1)) {
      message.value = 'El volumen debe estar entre 0 y 100 %.';
      return;
    }
    final next = value.value.copyWith(speechRate: rate, volume: volume);
    await _save(next);
    message.value = null;
    try {
      await _speech.configure(rate: next.speechRate, volume: next.volume);
      await _speech.speak(sample);
    } on Object {
      // Sin voz disponible: el ajuste queda guardado igual.
    }
  }

  /// Radio de alerta: solo de 5 a 100 m (HU13, CA2).
  Future<bool> setRadius(double radiusM) async {
    final error = InputValidators.radius(radiusM);
    if (error != null) {
      message.value = error;
      return false;
    }
    message.value = null;
    await _save(value.value.copyWith(alertRadiusM: radiusM));
    return true;
  }

  /// Umbral de confianza: solo de 0,30 a 0,90 (HU13, CA2).
  Future<bool> setConfidence(double threshold) async {
    final error = InputValidators.confidence(threshold);
    if (error != null) {
      message.value = error;
      return false;
    }
    message.value = null;
    await _save(value.value.copyWith(confidenceThreshold: threshold));
    return true;
  }

  /// Reproduce el patrón de «cerca» para comprobar que se siente, aunque la
  /// vibración de las alertas esté desactivada.
  Future<void> testVibration() async {
    await _haptics?.play(HapticPatterns.near);
  }

  Future<void> setVibration(bool enabled) =>
      _save(value.value.copyWith(vibration: enabled));

  Future<void> setAutoZones(bool enabled) =>
      _save(value.value.copyWith(autoZones: enabled));

  /// Fuente de video. Si se elige la cámara USB y no está conectada, se
  /// informa y se mantiene la del teléfono (HU13, CA3).
  Future<void> setVideoSource(VideoSourceKind kind) async {
    if (kind != VideoSourceKind.phone) {
      final usb = _sources.sources[kind];
      final available = usb != null && await usb.isAvailable();
      if (!available) {
        message.value = usbMissing;
        await _save(value.value.copyWith(videoSource: VideoSourceKind.phone));
        return;
      }
    }
    message.value = null;
    await _save(value.value.copyWith(videoSource: kind));
  }

  /// Restablece los valores por defecto conservando el perfil (HU13, CA4).
  Future<void> reset() async {
    await _save(value.value.resetKeepingProfile());
    message.value = resetDone;
  }

  static String rateLabel(double rate) =>
      '${rate.toStringAsFixed(1).replaceAll('.', ',')}×';

  static String percent(double v) => '${(v * 100).round()} %';

  static String confidenceLabel(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  static const double radiusStep = 5;
  static const double confidenceStep = 0.05;
  static const double rateStep = 0.1;
  static const double minRate = AppConstants.minSpeechRate;
  static const double maxRate = AppConstants.maxSpeechRate;
}
