import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/presentation/controllers/pin_controller.dart';
import 'package:eyesight_ai/presentation/controllers/theme_controller.dart';
import 'package:eyesight_ai/presentation/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/device_fakes.dart';
import '../../support/fakes.dart';

void main() {
  late InMemorySecureStore store;
  late PinGuard guard;
  late InMemorySettingsRepository settings;
  late FakeSpeech speech;
  late ThemeController theme;
  late List<String> routes;
  late DateTime now;

  setUp(() {
    store = InMemorySecureStore();
    now = DateTime(2026, 10, 7, 9);
    // Pocas iteraciones para que las pruebas sean rápidas.
    final hasher = PinHasher(iterations: 200);
    guard = PinGuard(
      store,
      hash: (pin) async => hasher.hash(pin),
      verify: (pin, hash) async => PinHasher.verify(pin, hash),
      clock: () => now,
    );
    settings = InMemorySettingsRepository();
    speech = FakeSpeech();
    theme = ThemeController();
    routes = [];
  });

  Future<PinController> build() async {
    final c = PinController(
      guard: guard,
      settings: settings,
      speech: speech,
      theme: theme,
      navigate: routes.add,
    );
    await c.load();
    return c;
  }

  void type(PinController c, String digits) {
    for (final d in digits.split('')) {
      c.addDigit(d);
    }
  }

  test('sin PIN pide crearlo; con PIN pide ingresarlo', () async {
    expect((await build()).mode.value, PinMode.create);
    await guard.setPin('2468');
    expect((await build()).mode.value, PinMode.verify);
  });

  test('crear y confirmar el PIN entra como acompañante (HU01, CA3)', () async {
    final c = await build();
    type(c, '2468');
    await c.submit();
    expect(c.mode.value, PinMode.confirm);
    expect(c.entered.value, isEmpty);

    type(c, '2468');
    await c.submit();
    expect(await guard.hasPin(), isTrue);
    expect(settings.value.profile, UserProfile.companion);
    expect(theme.profile.value, UserProfile.companion);
    expect(routes, [AppRoutes.companion]);
  });

  test('si la confirmación no coincide vuelve a crear el PIN', () async {
    final c = await build();
    type(c, '2468');
    await c.submit();
    type(c, '1357');
    await c.submit();
    expect(c.mode.value, PinMode.create);
    expect(c.error.value, contains('no coinciden'));
    expect(await guard.hasPin(), isFalse);
    expect(routes, isEmpty);
  });

  test('un PIN corto se rechaza con un mensaje (RNF12)', () async {
    final c = await build();
    type(c, '12');
    await c.submit();
    expect(c.mode.value, PinMode.create);
    expect(c.error.value, isNotNull);
  });

  test('PIN correcto entra; incorrecto informa los intentos restantes',
      () async {
    await guard.setPin('2468');
    final c = await build();
    type(c, '1111');
    await c.submit();
    expect(c.error.value, 'PIN incorrecto. Quedan 4 intentos.');
    expect(routes, isEmpty);

    type(c, '2468');
    await c.submit();
    expect(routes, [AppRoutes.companion]);
  });

  test('tras 5 intentos fallidos bloquea 60 segundos (RNF10)', () async {
    await guard.setPin('2468');
    final c = await build();
    for (var i = 0; i < 5; i++) {
      type(c, '1111');
      await c.submit();
    }
    expect(c.error.value, contains('Espera 60 segundos'));

    type(c, '2468');
    await c.submit();
    expect(routes, isEmpty);

    now = now.add(const Duration(seconds: 61));
    type(c, '2468');
    await c.submit();
    expect(routes, [AppRoutes.companion]);
  });

  test('admite máximo 6 dígitos y borra el último', () async {
    final c = await build();
    type(c, '12345678');
    expect(c.entered.value, '123456');
    c.backspace();
    expect(c.entered.value, '12345');
    c.entered.value = '';
    c.backspace();
    expect(c.entered.value, isEmpty);
  });

  test('escribir un dígito limpia el error anterior', () async {
    final c = await build();
    c.error.value = 'error';
    c.addDigit('1');
    expect(c.error.value, isNull);
  });

  test('cambiar de perfil borra el perfil guardado y vuelve a elegirlo',
      () async {
    settings.value = const AppSettings(profile: UserProfile.companion);
    theme.profile.value = UserProfile.companion;
    final c = await build();
    await c.changeProfile();
    expect(settings.value.profile, isNull);
    expect(theme.profile.value, isNull);
    expect(routes, [AppRoutes.profile]);
  });
}
