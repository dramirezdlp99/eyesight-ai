import 'dart:async';

import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/domain/usecases/zone_monitor.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:eyesight_ai/presentation/controllers/scanner_controller.dart';
import 'package:eyesight_ai/presentation/controllers/theme_controller.dart';
import 'package:eyesight_ai/presentation/theme/app_colors.dart';
import 'package:eyesight_ai/presentation/theme/app_theme.dart';
import 'package:eyesight_ai/presentation/views/scanner/scanner_view.dart';
import 'package:eyesight_ai/presentation/widgets/scanner_gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/builders.dart';
import '../../support/device_fakes.dart';
import '../../support/fakes.dart';
import '../../support/scanner_fakes.dart';
import '../../support/screen.dart';

void main() {
  late FakeSpeech speech;
  late ScannerController controller;
  late int profileChanges;

  tearDown(() {
    Get.delete<ScannerController>();
    Get.reset();
  });

  Future<void> pumpScanner(WidgetTester tester,
      {required bool lowVision}) async {
    usePhoneSize(tester);
    speech = FakeSpeech();
    profileChanges = 0;
    final zones = InMemoryZoneRepository();
    Get.put(
      ThemeController()
        ..profile.value =
            lowVision ? UserProfile.lowVision : UserProfile.totalBlindness,
    );
    controller = Get.put(
      ScannerController(
        detector: FakeDetector(),
        sources:
            VideoSourceSelector({VideoSourceKind.phone: FakeVideoSource()}),
        speech: speech,
        voice: FakeVoice(),
        haptics: FakeHaptics(),
        location: FakeLocation(),
        permissions: FakePermissions()..granted.addAll(AppPermission.values),
        wakelock: FakeWakelock(),
        settings: InMemorySettingsRepository(),
        zones: zones,
        history: InMemoryHistoryRepository(),
        zoneService: ZoneService(
          zones: zones,
          audit: InMemoryAuditRepository(),
          clock: () => t0,
        ),
        clock: () => t0,
        periodic: FakePeriodic().call,
        autoStart: false,
        listenForCommands: false,
      ),
    );
    await controller.startScan();
    speech.spoken.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: lowVision ? AppTheme.highContrast() : AppTheme.light(),
        home: ScannerView(onChangeProfile: () => profileChanges++),
      ),
    );
    await tester.pump();
  }

  Finder button(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );

  group('baja visión (HU05)', () {
    testWidgets('CA2: muestra los cuatro botones de al menos 48 dp',
        (tester) async {
      await pumpScanner(tester, lowVision: true);
      for (final label in ['Repetir', 'Silenciar', 'Marcar zona', 'Terminar']) {
        expect(button(label), findsOneWidget, reason: label);
        expect(tester.getSize(button(label)).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA1: el aviso se muestra en texto de al menos 24 sp',
        (tester) async {
      await pumpScanner(tester, lowVision: true);
      controller.headlineProximity.value = Proximity.near;
      controller.headline.value = 'Poste, cerca, al frente';
      await tester.pump();
      for (final shown in ['Poste', 'cerca, al frente']) {
        final text = tester.widget<Text>(find.text(shown));
        expect(text.style?.fontSize, greaterThanOrEqualTo(24), reason: shown);
      }
      expect(find.text('Cerca · vibra 3 veces'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Terminar» pregunta y «Sí, terminar» detiene el escáner',
        (tester) async {
      await pumpScanner(tester, lowVision: true);
      await tester.tap(button('Terminar'));
      await tester.pump();
      expect(find.text('Sí, terminar'), findsOneWidget);
      expect(speech.spoken.last, ScannerController.askStopMessage);

      await tester.tap(find.text('Sí, terminar'));
      await tester.pump();
      expect(controller.state.value, ScanState.stopped);
      expect(find.text('Iniciar escáner'), findsOneWidget);

      await tester.tap(find.text('Cambiar de perfil'));
      expect(profileChanges, 1);
    });

    testWidgets('«Repetir» sin alertas lo informa por voz', (tester) async {
      await pumpScanner(tester, lowVision: true);
      await tester.tap(button('Repetir'));
      await tester.pump();
      expect(speech.spoken.last, ScannerController.noAlertMessage);
    });
  });

  group('ceguera total: gestos (HU07, HU09)', () {
    testWidgets('doble toque repite', (tester) async {
      await pumpScanner(tester, lowVision: false);
      final area = find.byType(ScannerGestures);
      await tester.tap(area);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(area);
      await tester.pump(const Duration(milliseconds: 400));
      expect(speech.spoken, [ScannerController.noAlertMessage]);
    });

    testWidgets('deslizar el dedo silencia la voz', (tester) async {
      await pumpScanner(tester, lowVision: false);
      await tester.fling(
        find.byType(ScannerGestures),
        const Offset(-150, 0),
        1000,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.muted.value, isTrue);
      expect(speech.spoken.last, ScannerController.mutedMessage);
    });

    testWidgets('mantener presionado 2 s marca una zona', (tester) async {
      await pumpScanner(tester, lowVision: false);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ScannerGestures)),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(speech.spoken, isEmpty);
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();
      // Sin GPS (posición nula) informa que no fue posible registrarla.
      expect(speech.spoken.last, ScannerController.zoneNoGpsMessage);
    });

    testWidgets('las acciones también están disponibles para TalkBack',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScanner(tester, lowVision: false);
      expect(
        find.bySemanticsLabel(RegExp('Área del escáner')),
        findsOneWidget,
      );
      expect(find.text('Escáner'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('diseño Barniz de Pasto', () {
    testWidgets('sin alertas muestra la tarjeta de espera y los gestos',
        (tester) async {
      await pumpScanner(tester, lowVision: false);
      expect(find.text('Sin alertas por ahora'), findsOneWidget);
      expect(find.text('Doble toque'), findsOneWidget);
      expect(find.text('Mantener 2 s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el obstáculo cercano se muestra en carmín', (tester) async {
      await pumpScanner(tester, lowVision: false);
      controller.headlineProximity.value = Proximity.near;
      controller.headline.value = 'Poste, cerca, al frente';
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Poste'), findsOneWidget);
      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Poste'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.carmin);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el aviso de zona muestra el tipo y la distancia (HU08)',
        (tester) async {
      await pumpScanner(tester, lowVision: false);
      final warning = ZoneWarning(zone: zone(type: 'step'), distanceM: 18);
      controller.activeZone.value = warning;
      controller.headlineProximity.value = null;
      controller.headline.value = warning.message;
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Escalón'), findsOneWidget);
      expect(find.text('a 18 m · un pulso largo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la zona guardada aparece en verde y se desvanece',
        (tester) async {
      await pumpScanner(tester, lowVision: false);
      controller.savedZone.value = zone();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Zona de hueco guardada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Zona de hueco guardada'), findsNothing);
    });

    testWidgets('marcar zona por voz muestra los cuatro tipos (HU07)',
        (tester) async {
      await pumpScanner(tester, lowVision: false);
      controller.dialog.value = ScannerDialog.zoneType;
      await tester.pump();
      for (final label in ['Hueco', 'Escalón', 'Obra', 'Otro', 'Cancelar']) {
        expect(button(label), findsOneWidget, reason: label);
      }
      await tester.tap(button('Cancelar'));
      await tester.pump();
      expect(controller.dialog.value, ScannerDialog.none);
      expect(speech.spoken.last, ScannerController.zoneCanceledMessage);
    });

    testWidgets('detenido muestra el resumen de la sesión', (tester) async {
      await pumpScanner(tester, lowVision: false);
      // Se detiene sin esperar, como en la prueba de humo.
      unawaited(controller.stopScan());
      await tester.pump();
      expect(find.text('Escáner detenido'), findsOneWidget);
      expect(find.text('alertas'), findsOneWidget);
      expect(find.text('zonas nuevas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
