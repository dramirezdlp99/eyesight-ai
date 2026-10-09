import 'dart:async';

import 'package:eyesight_ai/core/ai/i_obstacle_detector.dart';
import 'package:eyesight_ai/core/device/haptics.dart';
import 'package:eyesight_ai/core/device/location_service.dart';
import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/speech_service.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/core/device/voice_input.dart';
import 'package:eyesight_ai/core/device/wakelock_service.dart';
import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/domain/repositories/i_history_repository.dart';
import 'package:eyesight_ai/domain/repositories/i_settings_repository.dart';
import 'package:eyesight_ai/domain/repositories/i_zone_repository.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:eyesight_ai/main.dart';
import 'package:eyesight_ai/presentation/controllers/profile_controller.dart';
import 'package:eyesight_ai/presentation/controllers/scanner_controller.dart';
import 'package:eyesight_ai/presentation/controllers/theme_controller.dart';
import 'package:eyesight_ai/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/device_fakes.dart';
import '../support/fakes.dart';
import '../support/scanner_fakes.dart';
import '../support/screen.dart';

void main() {
  late FakeSpeech speech;

  void register(WidgetTester tester,
      [AppSettings initial = const AppSettings()]) {
    usePhoneSize(tester);
    speech = FakeSpeech();
    Get.put<ISettingsRepository>(InMemorySettingsRepository(initial));
    Get.put<ISpeechService>(speech);
    // Sin reconocimiento continuo: el escáner no deja temporizadores
    // pendientes al terminar la prueba.
    Get.put<IVoiceInput>(FakeVoice()..available = false);
    Get.put<PinGuard>(PinGuard(InMemorySecureStore()));
    Get.put<ThemeController>(ThemeController());
    // Dependencias del escáner con dobles de prueba.
    final zones = InMemoryZoneRepository();
    Get.put<IObstacleDetector>(FakeDetector());
    Get.put<VideoSourceSelector>(
      VideoSourceSelector({VideoSourceKind.phone: FakeVideoSource()}),
    );
    Get.put<IHaptics>(FakeHaptics());
    Get.put<ILocationService>(FakeLocation());
    Get.put<IPermissionGuard>(
      FakePermissions()..granted.addAll(AppPermission.values),
    );
    Get.put<IWakelock>(FakeWakelock());
    Get.put<IZoneRepository>(zones);
    Get.put<IHistoryRepository>(InMemoryHistoryRepository());
    Get.put<ZoneService>(
      ZoneService(zones: zones, audit: InMemoryAuditRepository()),
    );
  }

  /// Pasa el splash (1,8 s) y la transición de pantalla.
  Future<void> passSplash(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  tearDown(() => Get.reset());

  testWidgets('el splash anuncia el nombre como encabezado', (tester) async {
    final semantics = tester.ensureSemantics();
    register(tester);
    await tester.pumpWidget(const EyeSightApp());
    expect(find.text('EyeSight AI'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('EyeSight AI')),
      isSemantics(isHeader: true, label: 'EyeSight AI'),
    );
    await passSplash(tester);
    semantics.dispose();
  });

  testWidgets('sin perfil guardado pasa a elegirlo y lo anuncia (HU01)',
      (tester) async {
    register(tester);
    await tester.pumpWidget(const EyeSightApp());
    await passSplash(tester);

    expect(find.text('Ceguera total'), findsOneWidget);
    expect(find.text('Baja visión'), findsOneWidget);
    // La lista solo construye lo que cabe en pantalla: se desplaza hasta el
    // tercer botón.
    await tester.scrollUntilVisible(find.text('Acompañante'), 200);
    expect(find.text('Acompañante'), findsOneWidget);
    expect(speech.spoken.first, ProfileController.welcome);
  });

  testWidgets(
      'con perfil de baja visión abre el escáner en alto contraste '
      '(HU01 CA5, HU05)', (tester) async {
    register(tester, const AppSettings(profile: UserProfile.lowVision));
    await tester.pumpWidget(const EyeSightApp());
    await passSplash(tester);

    expect(find.text('Escáner'), findsOneWidget);
    expect(Get.find<ThemeController>().highContrast, isTrue);
    final context = tester.element(find.text('Escáner'));
    expect(
      Theme.of(context).colorScheme.primary,
      AppColors.contrastPrimary,
    );
    // HU02: el escáner inicia solo y muestra los botones grandes (HU05).
    final scanner = Get.find<ScannerController>();
    expect(scanner.state.value, ScanState.scanning);
    expect(speech.spoken, contains(ScannerController.startedMessage));
    expect(find.text('Repetir'), findsOneWidget);
    // Se detiene sin esperar: el temporizador del GPS se cancela de
    // inmediato y la prueba no depende de cerrar la cámara simulada.
    unawaited(scanner.stopScan());
    await tester.pump();
  });

  testWidgets('el acompañante con perfil guardado debe ingresar el PIN',
      (tester) async {
    register(tester, const AppSettings(profile: UserProfile.companion));
    await tester.pumpWidget(const EyeSightApp());
    await passSplash(tester);
    expect(find.text('Crea un PIN de 4 a 6 dígitos'), findsOneWidget);
  });

  testWidgets('si falla el arranque muestra el error en lugar de cerrarse',
      (tester) async {
    await tester.pumpWidget(
      const EyeSightApp(startupError: 'No se pudo abrir el almacenamiento'),
    );
    expect(find.text('No se pudo abrir el almacenamiento'), findsOneWidget);
  });
}
