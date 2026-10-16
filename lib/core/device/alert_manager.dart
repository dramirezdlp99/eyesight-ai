import 'dart:async';

import '../../domain/entities/proximity.dart';
import '../../domain/usecases/alert_policy.dart';
import '../../domain/usecases/zone_monitor.dart';
import '../config/app_constants.dart';
import 'haptics.dart';
import 'speech_service.dart';

/// Emite las alertas por voz y vibración (diagrama de clases: AlertManager).
///
/// * Obstáculos: voz y el patrón de pulsos de su cercanía (HU03, HU04).
/// * Zonas: voz y un pulso largo (HU04 CA3, HU08).
/// * Silencio de 10 s: calla la voz, pero la vibración de lo cercano sigue
///   (HU09, CA2).
/// * Sin vibración en los ajustes: solo voz (HU04, CA4).
class AlertManager {
  AlertManager({
    required ISpeechService speech,
    required IHaptics haptics,
  })  : _speech = speech,
        _haptics = haptics;

  final ISpeechService _speech;
  final IHaptics _haptics;

  bool vibration = true;
  DateTime? _mutedUntil;
  int _speaking = 0;

  /// `true` mientras la app está hablando (no se escuchan comandos).
  bool get speaking => _speaking > 0;

  bool isMuted(DateTime now) {
    final until = _mutedUntil;
    return until != null && now.isBefore(until);
  }

  void mute(DateTime now) => _mutedUntil = now.add(AppConstants.muteDuration);

  void reset() {
    _mutedUntil = null;
  }

  /// Alerta de un obstáculo.
  void announce(AlertDecision decision, DateTime now) {
    final muted = isMuted(now);
    final near = decision.detection.proximity == Proximity.near;
    if (vibration && (!muted || near)) {
      unawaited(_haptics.play(decision.vibrationPattern));
    }
    if (!muted) {
      unawaited(say(decision.message));
    }
  }

  /// Aviso preventivo de una zona registrada.
  Future<void> warnZone(ZoneWarning warning, DateTime now) async {
    if (vibration) {
      unawaited(_haptics.play(HapticPatterns.zone));
    }
    if (!isMuted(now)) {
      await say(warning.message);
    }
  }

  /// Confirmación de una zona guardada: pulso largo.
  void confirmZone() {
    if (vibration) {
      unawaited(_haptics.play(HapticPatterns.zone));
    }
  }

  /// Habla [text]. Si la voz falla, la vibración y la pantalla siguen.
  Future<void> say(String text) async {
    _speaking++;
    try {
      await _speech.speak(text);
    } on Object {
      // Sin voz disponible: no se detiene el escáner (RNF05).
    } finally {
      _speaking--;
    }
  }
}
