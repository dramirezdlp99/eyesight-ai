import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:eyesight_ai/domain/entities/detection_record.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:eyesight_ai/presentation/controllers/history_controller.dart';
import 'package:eyesight_ai/presentation/controllers/privacy_controller.dart';
import 'package:eyesight_ai/presentation/controllers/settings_controller.dart';
import 'package:eyesight_ai/presentation/controllers/test_mode_controller.dart';
import 'package:eyesight_ai/presentation/controllers/zones_controller.dart';
import 'package:eyesight_ai/presentation/theme/app_theme.dart';
import 'package:eyesight_ai/presentation/views/companion/companion_shell_view.dart';
import 'package:eyesight_ai/presentation/views/companion/edit_zone_view.dart';
import 'package:eyesight_ai/presentation/views/companion/history_view.dart';
import 'package:eyesight_ai/presentation/views/companion/privacy_view.dart';
import 'package:eyesight_ai/presentation/views/companion/settings_view.dart';
import 'package:eyesight_ai/presentation/views/companion/test_mode_view.dart';
import 'package:eyesight_ai/presentation/views/companion/zones_view.dart';
import 'package:eyesight_ai/presentation/widgets/companion_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/builders.dart';
import '../../support/device_fakes.dart';
import '../../support/fakes.dart';
import '../../support/scanner_fakes.dart';
import '../../support/screen.dart';

void main() {
  late InMemoryZoneRepository zones;
  late InMemoryAuditRepository audit;
  late InMemoryHistoryRepository history;
  late InMemorySettingsRepository settings;
  late FakeSpeech speech;
  late FakePermissions permissions;
  late int wipes;
  late int profileChanges;

  setUp(() {
    zones = InMemoryZoneRepository()
      ..zones['a'] = zone(id: 'a', lastSeen: t0)
      ..zones['m'] = zone(
        id: 'm',
        type: 'step',
        origin: ZoneOrigin.manual,
        lastSeen: t0.subtract(const Duration(days: 1)),
      );
    audit = InMemoryAuditRepository();
    history = InMemoryHistoryRepository()
      ..records.addAll([
        DetectionRecord(
          label: 'pole',
          confidence: 0.82,
          proximity: Proximity.near,
          timestamp: t0.subtract(const Duration(minutes: 5)),
        ),
        DetectionRecord(
          label: 'person',
          confidence: 0.7,
          proximity: Proximity.medium,
          timestamp: t0.subtract(const Duration(days: 12)),
        ),
      ]);
    settings = InMemorySettingsRepository();
    speech = FakeSpeech();
    permissions = FakePermissions()..granted.add(AppPermission.camera);
    wipes = 0;
    profileChanges = 0;
  });

  tearDown(Get.reset);

  void putControllers() {
    Get.put(
      ZonesController(
        zones: zones,
        service: ZoneService(zones: zones, audit: audit, clock: () => t0),
        location: FakeLocation(),
        permissions: permissions,
        clock: () => t0,
      ),
    );
    Get.put(HistoryController(history: history, clock: () => t0));
    Get.put(
      SettingsController(
        settings: settings,
        speech: speech,
        sources: VideoSourceSelector({
          VideoSourceKind.phone: FakeVideoSource(),
          VideoSourceKind.usb:
              FakeVideoSource(kind: VideoSourceKind.usb, available: false),
        }),
      ),
    );
    final hasher = PinHasher(iterations: 200);
    Get.put(
      PrivacyController(
        zones: zones,
        history: history,
        audit: audit,
        permissions: permissions,
        pin: PinGuard(
          InMemorySecureStore(),
          hash: (p) async => hasher.hash(p),
          verify: (p, h) async => PinHasher.verify(p, h),
        ),
        wipe: () async => wipes++,
        navigate: (_) {},
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget home,
      {bool tall = false}) async {
    usePhoneSize(tester);
    if (tall) {
      tester.view.physicalSize = const Size(720, 4800);
    }
    putControllers();
    await Get.find<ZonesController>().load();
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: home));
    await tester.pump();
  }

  Widget scaffold(Widget child) => Scaffold(body: child);

  testWidgets('el inicio del acompañante cambia de pestaña', (tester) async {
    await pump(
      tester,
      CompanionShellView(
        baseMap: false,
        onChangeProfile: () => profileChanges++,
      ),
    );
    // La primera es la de las pestañas; la lista desplegable del Historial
    // usa otra por dentro.
    IndexedStack stack() => tester.widget(find.byType(IndexedStack).first);
    expect(stack().index, 0);
    for (final (i, tab) in CompanionTab.values.indexed) {
      await tester.tap(
        find.descendant(
            of: find.byType(PillNav), matching: find.text(tab.label)),
      );
      await tester.pump();
      expect(stack().index, i);
    }
    expect(tester.takeException(), isNull);
    // La píldora mide lo que sus botones, no toda la pantalla.
    expect(tester.getSize(find.byType(PillNav)).height, lessThan(120));
  });

  testWidgets('«atrás» vuelve al Mapa y desde el Mapa pregunta antes de salir',
      (tester) async {
    var changes = 0;
    await pump(
      tester,
      CompanionShellView(baseMap: false, onChangeProfile: () => changes++),
    );
    // La primera es la de las pestañas; la lista desplegable del Historial
    // usa otra por dentro.
    IndexedStack stack() => tester.widget(find.byType(IndexedStack).first);
    await tester.tap(
      find.descendant(
          of: find.byType(PillNav), matching: find.text('Historial')),
    );
    await tester.pump();
    expect(stack().index, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(stack().index, 0);
    // El botón «Volver» de la cabecera también regresa al Mapa.
    await tester.tap(
      find.descendant(of: find.byType(PillNav), matching: find.text('Ajustes')),
    );
    await tester.pump();
    expect(stack().index, 2);
    await tester.tap(find.text('Volver').hitTestable());
    await tester.pump();
    expect(stack().index, 0);
    // Desde el Mapa se cambia de perfil sin cerrar la app.
    await tester.tap(find.text('Cambiar de perfil').hitTestable());
    expect(changes, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de EyeSight AI?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionShellView), findsOneWidget);
  });

  group('Mapa y lista (HU10)', () {
    testWidgets('CA1 y CA3: lista con origen y filtro', (tester) async {
      String? opened;
      // Pantalla alta: la lista construye todas las zonas sin desplazarse.
      await pump(
        tester,
        scaffold(ZonesView(baseMap: false, onOpenZone: (id) => opened = id)),
        tall: true,
      );
      expect(find.text('Hueco'), findsOneWidget);
      expect(find.text('Escalón'), findsOneWidget);
      expect(find.textContaining('Automática · 1 registro'), findsOneWidget);

      await tester.tap(find.text('Manuales'));
      await tester.pump();
      expect(find.text('Hueco'), findsNothing);
      expect(find.text('Escalón'), findsOneWidget);

      // CA4: tocar una zona abre su edición.
      await tester.tap(find.text('Escalón'));
      expect(opened, 'm');
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA2: sin internet la lista se muestra completa',
        (tester) async {
      await pump(tester, scaffold(const ZonesView(baseMap: false)));
      expect(find.byType(ZonesView), findsOneWidget);
      expect(find.text('Hueco'), findsOneWidget);
    });
  });

  group('Editar zona (HU11)', () {
    testWidgets('CA1: cambia el tipo y guarda', (tester) async {
      var done = 0;
      await pump(tester, EditZoneView(zoneId: 'a', onDone: () => done++));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Poste'));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pump();
      expect(zones.zones['a']!.type, 'pole');
      expect(done, 1);
    });

    testWidgets('CA2: una nota de más de 100 caracteres se rechaza',
        (tester) async {
      var done = 0;
      await pump(tester, EditZoneView(zoneId: 'a', onDone: () => done++));
      await tester.enterText(find.byType(TextField), 'x' * 101);
      await tester.pump();
      expect(find.textContaining('100 caracteres'), findsWidgets);
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pump();
      expect(done, 0);
      expect(zones.zones['a']!.note, '');
    });

    testWidgets('CA3: eliminar pide confirmación y borra la zona',
        (tester) async {
      var done = 0;
      await pump(tester, EditZoneView(zoneId: 'm', onDone: () => done++));
      await tester.ensureVisible(find.text('Eliminar zona'));
      await tester.pump();
      await tester.tap(find.text('Eliminar zona'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar esta zona?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(zones.zones.containsKey('m'), isFalse);
      expect(done, 1);
    });

    testWidgets('una zona que ya no existe se informa', (tester) async {
      await pump(tester, const EditZoneView(zoneId: 'nada'));
      expect(find.text('La zona ya no existe.'), findsOneWidget);
    });
  });

  testWidgets('Historial (HU12): lista, filtro de fecha y gráfica',
      (tester) async {
    await pump(tester, scaffold(const HistoryView()));
    expect(find.text('Confianza 0,82'), findsOneWidget);
    expect(find.text('Confianza 0,70'), findsNothing);
    expect(find.text('1 alerta · 7 días'), findsOneWidget);
    await tester.tap(find.text('30 días'));
    await tester.pump();
    expect(find.text('Confianza 0,70'), findsOneWidget);
    expect(find.text('2 alertas · 30 días'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ajustes (HU13): vibración y cámara USB ausente', (tester) async {
    await pump(
      tester,
      scaffold(SettingsView(onChangeProfile: () => profileChanges++)),
    );
    await tester.tap(find.text('Vibración'));
    await tester.pump();
    expect(settings.value.vibration, isFalse);
    await tester.ensureVisible(find.text('USB en gafas'));
    await tester.pump();
    await tester.tap(find.text('USB en gafas'));
    await tester.pump();
    expect(settings.value.videoSource, VideoSourceKind.phone);
    await tester.ensureVisible(find.text('Cambiar de perfil'));
    await tester.pump();
    await tester.tap(find.text('Cambiar de perfil'));
    expect(profileChanges, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Privacidad (HU14): cifras y borrado con ELIMINAR',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, scaffold(const PrivacyView()));
    expect(find.bySemanticsLabel('2 zonas'), findsOneWidget);
    expect(find.text('Concedido'), findsOneWidget);
    await tester.ensureVisible(find.text('Borrar mis datos'));
    await tester.pump();
    final button = find.ancestor(
      of: find.text('Borrar mis datos'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'ELIMINAR');
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pump();
    expect(wipes, 1);
    semantics.dispose();
  });

  testWidgets('Modo de pruebas (HU15): inicia y detiene la medición',
      (tester) async {
    usePhoneSize(tester);
    final controller = Get.put(
      TestModeController(
        detector: FakeDetector(),
        sources:
            VideoSourceSelector({VideoSourceKind.phone: FakeVideoSource()}),
        settings: settings,
        speech: speech,
        haptics: FakeHaptics(),
        location: FakeLocation(),
        permissions: FakePermissions()..granted.addAll(AppPermission.values),
        wakelock: FakeWakelock(),
        exporter: FakeFileExporter(),
        clock: () => t0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const TestModeView()),
    );
    expect(find.text('Modo de pruebas'), findsOneWidget);
    await tester.ensureVisible(find.text('Iniciar medición'));
    await tester.pump();
    await tester.tap(find.text('Iniciar medición'));
    await tester.pump();
    expect(controller.running, isTrue);
    await tester.ensureVisible(find.text('Detener'));
    await tester.pump();
    await tester.tap(find.text('Detener'));
    await tester.pump();
    expect(controller.running, isFalse);
    expect(tester.takeException(), isNull);
  });
}
