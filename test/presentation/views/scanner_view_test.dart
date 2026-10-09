import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:eyesight_ai/presentation/controllers/scanner_controller.dart';
import 'package:eyesight_ai/presentation/controllers/theme_controller.dart';
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
      controller.headline.value = 'Poste, cerca, al frente';
      await tester.pump();
      final text = tester.widget<Text>(find.text('Poste, cerca, al frente'));
      final context = tester.element(find.text('Poste, cerca, al frente'));
      final size = text.style?.fontSize ??
          DefaultTextStyle.of(context).style.fontSize ??
          0;
      expect(size, greaterThanOrEqualTo(24));
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
}
