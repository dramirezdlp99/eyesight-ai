import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/presentation/controllers/profile_controller.dart';
import 'package:eyesight_ai/presentation/controllers/theme_controller.dart';
import 'package:eyesight_ai/presentation/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/device_fakes.dart';
import '../../support/fakes.dart';

void main() {
  late FakeSpeech speech;
  late InMemorySettingsRepository settings;
  late ThemeController theme;
  late List<String> routes;

  setUp(() {
    speech = FakeSpeech();
    settings = InMemorySettingsRepository();
    theme = ThemeController();
    routes = [];
  });

  ProfileController build(FakeVoice voice) => ProfileController(
        speech: speech,
        voice: voice,
        settings: settings,
        theme: theme,
        navigate: routes.add,
        autoStart: false,
      );

  test('anuncia los perfiles al empezar (HU01, CA1)', () async {
    final c = build(FakeVoice(['ceguera total']));
    await c.start();
    expect(speech.spoken.first, ProfileController.welcome);
  });

  test('por voz «baja visión» guarda el perfil y abre el escáner (CA2)',
      () async {
    final voice = FakeVoice(['baja visión']);
    final c = build(voice);
    await c.start();

    expect(settings.value.profile, UserProfile.lowVision);
    expect(theme.highContrast, isTrue);
    expect(routes, [AppRoutes.scanner]);
    expect(speech.spoken.last, 'Perfil baja visión seleccionado.');
    expect(c.phase.value, ProfilePhase.done);
    expect(voice.stops, 1);
  });

  test('por voz «ceguera total» abre el escáner sin alto contraste', () async {
    final c = build(FakeVoice(['ceguera total']));
    await c.start();
    expect(settings.value.profile, UserProfile.totalBlindness);
    expect(theme.highContrast, isFalse);
    expect(routes, [AppRoutes.scanner]);
  });

  test('si no entiende, repite la pregunta y acepta el segundo intento',
      () async {
    final voice = FakeVoice(['hola', 'ceguera total']);
    final c = build(voice);
    await c.start();

    expect(speech.spoken, contains(ProfileController.retry));
    expect(voice.listens, 2);
    expect(c.failures, 1);
    expect(routes, [AppRoutes.scanner]);
  });

  test('tras dos fallos pasa a los botones y no navega (CA4)', () async {
    final voice = FakeVoice([null, 'qué']);
    final c = build(voice);
    await c.start();

    expect(voice.listens, ProfileController.maxVoiceAttempts);
    expect(speech.spoken.last, ProfileController.fallback);
    expect(c.phase.value, ProfilePhase.idle);
    expect(routes, isEmpty);
    expect(settings.value.profile, isNull);
  });

  test('el acompañante va al PIN sin guardar el perfil todavía (CA3)',
      () async {
    final voice = FakeVoice();
    final c = build(voice);
    await c.select(UserProfile.companion);

    expect(routes, [AppRoutes.pin]);
    expect(settings.value.profile, isNull);
    expect(voice.stops, 1);
  });

  test('una segunda selección se ignora', () async {
    final c = build(FakeVoice());
    await c.select(UserProfile.totalBlindness);
    await c.select(UserProfile.lowVision);
    expect(routes, [AppRoutes.scanner]);
    expect(settings.value.profile, UserProfile.totalBlindness);
  });

  test('tocar un botón mientras escucha detiene la escucha por voz', () async {
    final voice = FakeVoice(['baja visión']);
    final c = build(voice);
    await c.select(UserProfile.totalBlindness);
    await c.listenForProfile();
    expect(voice.listens, 0);
    expect(settings.value.profile, UserProfile.totalBlindness);
  });

  test('conserva los demás ajustes al guardar el perfil', () async {
    settings.value = const AppSettings(speechRate: 1.5, alertRadiusM: 40);
    final c = build(FakeVoice());
    await c.select(UserProfile.lowVision);
    expect(settings.value.speechRate, 1.5);
    expect(settings.value.alertRadiusM, 40);
  });
}
