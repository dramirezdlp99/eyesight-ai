import 'package:eyesight_ai/core/device/alert_manager.dart';
import 'package:eyesight_ai/core/device/earcons.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/usecases/alert_policy.dart';
import 'package:eyesight_ai/domain/usecases/zone_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/device_fakes.dart';

class _FailingSpeech extends FakeSpeech {
  @override
  Future<void> speak(String text, {bool interrupt = true}) async =>
      throw StateError('sin voz');
}

void main() {
  late FakeSpeech speech;
  late FakeHaptics haptics;
  late FakeEarcons earcons;
  late AlertManager alerts;

  setUp(() {
    speech = FakeSpeech();
    haptics = FakeHaptics();
    earcons = FakeEarcons();
    alerts = AlertManager(speech: speech, haptics: haptics, earcons: earcons);
  });

  AlertDecision decision(Proximity p) => AlertDecision(
        detection: det('pole', proximity: p),
        message: 'Poste, ${p.spoken}, al frente',
        vibrationPattern: HapticPatterns.forProximity(p),
      );

  test('los pitidos repiten el código de la vibración', () async {
    alerts
      ..announce(decision(Proximity.near), t0)
      ..announce(decision(Proximity.far), t0)
      ..confirmZone();
    await Future<void>.delayed(Duration.zero);
    expect(earcons.played, [Earcons.near, Earcons.far, Earcons.zone]);
    expect(Earcons.near, hasLength(3));
    expect(Earcons.medium, hasLength(2));
    expect(Earcons.far, hasLength(1));
  });

  test('en silencio solo pita lo cercano y sin pitidos no suena', () async {
    alerts
      ..mute(t0)
      ..announce(decision(Proximity.medium), t0)
      ..announce(decision(Proximity.near), t0);
    await Future<void>.delayed(Duration.zero);
    expect(earcons.played, [Earcons.near]);
    alerts
      ..reset()
      ..beeps = false
      ..announce(decision(Proximity.near), t0);
    await Future<void>.delayed(Duration.zero);
    expect(earcons.played, hasLength(1));
    expect(haptics.played, hasLength(2));
  });

  test('anuncia con voz y el patrón de vibración de la cercanía (HU04)',
      () async {
    alerts.announce(decision(Proximity.medium), t0);
    await Future<void>.delayed(Duration.zero);
    expect(speech.spoken, ['Poste, a media distancia, al frente']);
    expect(haptics.played, [HapticPatterns.medium]);
  });

  test('en silencio calla la voz, pero lo cercano sigue vibrando (HU09)',
      () async {
    alerts.mute(t0);
    expect(alerts.isMuted(t0), isTrue);
    alerts
      ..announce(decision(Proximity.medium), t0)
      ..announce(decision(Proximity.near), t0);
    await Future<void>.delayed(Duration.zero);
    expect(speech.spoken, isEmpty);
    expect(haptics.played, [HapticPatterns.near]);
    expect(alerts.isMuted(t0.add(const Duration(seconds: 10))), isFalse);
  });

  test('sin vibración en los ajustes solo habla (HU04, CA4)', () async {
    alerts.vibration = false;
    alerts.announce(decision(Proximity.near), t0);
    alerts.confirmZone();
    await Future<void>.delayed(Duration.zero);
    expect(haptics.played, isEmpty);
    expect(speech.spoken, hasLength(1));
  });

  test('aviso de zona: un pulso largo y la voz', () async {
    await alerts.warnZone(
      ZoneWarning(zone: zone(), distanceM: 18),
      t0,
    );
    expect(haptics.played, [HapticPatterns.zone]);
    expect(speech.spoken, ['Atención: hueco a 18 metros']);
  });

  test('si la voz falla no se interrumpe (RNF05)', () async {
    final failing = AlertManager(speech: _FailingSpeech(), haptics: haptics);
    await failing.say('Hola');
    expect(failing.speaking, isFalse);
  });

  test('reset quita el silencio', () {
    alerts
      ..mute(t0)
      ..reset();
    expect(alerts.isMuted(t0), isFalse);
  });
}
