import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/presentation/controllers/pin_controller.dart';
import 'package:eyesight_ai/presentation/controllers/profile_controller.dart';
import 'package:eyesight_ai/presentation/routes/app_routes.dart';
import 'package:eyesight_ai/presentation/theme/app_theme.dart';
import 'package:eyesight_ai/presentation/views/pin/pin_view.dart';
import 'package:eyesight_ai/presentation/views/profile/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/device_fakes.dart';
import '../../support/fakes.dart';
import '../../support/screen.dart';

void main() {
  late List<String> routes;
  late InMemorySettingsRepository settings;

  setUp(() {
    routes = [];
    settings = InMemorySettingsRepository();
  });

  tearDown(() => Get.reset());

  group('ProfileView (HU01)', () {
    Future<void> pumpProfile(WidgetTester tester, ThemeData theme) async {
      usePhoneSize(tester);
      Get.put(
        ProfileController(
          speech: FakeSpeech(),
          voice: FakeVoice(),
          settings: settings,
          navigate: routes.add,
          autoStart: false,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const ProfileView()),
      );
    }

    testWidgets('muestra los tres perfiles como botones accesibles',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpProfile(tester, AppTheme.light());

      expect(find.text('Ceguera total'), findsOneWidget);
      expect(find.text('Baja visión'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Baja visión')),
        isSemantics(
          isButton: true,
          label: 'Baja visión. Además, pantalla de alto contraste',
        ),
      );
      // La lista solo construye lo que cabe en pantalla: se desplaza hasta el
      // tercer botón.
      await tester.scrollUntilVisible(find.text('Acompañante'), 200);
      expect(find.text('Acompañante'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tocar «Baja visión» guarda el perfil y abre el escáner',
        (tester) async {
      await pumpProfile(tester, AppTheme.light());
      await tester.tap(find.text('Baja visión'));
      await tester.pump();

      expect(settings.value.profile, UserProfile.lowVision);
      expect(routes, [AppRoutes.scanner]);
    });

    testWidgets('cabe sin desbordarse con el tema de alto contraste',
        (tester) async {
      await pumpProfile(tester, AppTheme.highContrast());
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Acompañante'), 200);
      await tester.tap(find.text('Acompañante'));
      await tester.pump();
      expect(routes, [AppRoutes.pin]);
    });
  });

  group('PinView (HU01, CA3)', () {
    Future<PinGuard> pumpPin(WidgetTester tester) async {
      usePhoneSize(tester);
      final hasher = PinHasher(iterations: 200);
      final guard = PinGuard(
        InMemorySecureStore(),
        hash: (pin) async => hasher.hash(pin),
        verify: (pin, hash) async => PinHasher.verify(pin, hash),
      );
      Get.put(
        PinController(
          guard: guard,
          settings: settings,
          speech: FakeSpeech(),
          navigate: routes.add,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const PinView()),
      );
      await tester.pump();
      return guard;
    }

    Future<void> typeAndConfirm(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.tap(find.text('OK'));
      await tester.pump();
    }

    testWidgets('crear el PIN con el teclado entra como acompañante',
        (tester) async {
      final guard = await pumpPin(tester);
      expect(find.text('Crea un PIN de 4 a 6 dígitos'), findsOneWidget);

      await typeAndConfirm(tester, '2468');
      expect(find.text('Repite el PIN'), findsOneWidget);

      await typeAndConfirm(tester, '2468');
      expect(await guard.hasPin(), isTrue);
      expect(routes, [AppRoutes.companion]);
    });

    testWidgets('el contador de dígitos se anuncia sin revelar el PIN',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPin(tester);
      await tester.tap(find.text('7'));
      await tester.tap(find.text('3'));
      await tester.pump();
      expect(find.bySemanticsLabel('2 dígitos ingresados'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('«Cambiar de perfil» vuelve a la selección', (tester) async {
      await pumpPin(tester);
      await tester.tap(find.text('Cambiar de perfil'));
      await tester.pump();
      expect(routes, [AppRoutes.profile]);
    });
  });
}
