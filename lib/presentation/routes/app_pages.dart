import 'package:get/get.dart';

import '../../core/ai/i_obstacle_detector.dart';
import '../../core/device/earcons.dart';
import '../../core/device/file_exporter.dart';
import '../../core/device/haptics.dart';
import '../../core/device/location_service.dart';
import '../../core/device/permission_guard.dart';
import '../../core/device/speech_service.dart';
import '../../core/device/video_source_selector.dart';
import '../../core/device/voice_input.dart';
import '../../core/device/wakelock_service.dart';
import '../../core/security/data_wipe_service.dart';
import '../../core/security/pin_guard.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_audit_repository.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../../domain/usecases/zone_service.dart';
import '../bindings/app_bindings.dart';
import '../controllers/history_controller.dart';
import '../controllers/pin_controller.dart';
import '../controllers/privacy_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/scanner_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/test_mode_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/zones_controller.dart';
import '../views/companion/companion_shell_view.dart';
import '../views/companion/edit_zone_view.dart';
import '../views/companion/test_mode_view.dart';
import '../views/pin/pin_view.dart';
import '../views/profile/profile_view.dart';
import '../views/scanner/scanner_view.dart';
import '../views/splash/splash_view.dart';
import 'app_routes.dart';

/// Pantallas y sus dependencias (inyección con GetX, numeral 3.12.4).
abstract final class AppPages {
  static void go(String route) => Get.offAllNamed<void>(route);

  /// Pantalla inicial según el perfil guardado (HU01, CA5).
  static Future<String> initialRouteFor(ISettingsRepository settings) async {
    final profile = (await settings.load()).profile;
    final theme = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : null;
    theme?.profile.value = profile;
    return switch (profile) {
      null => AppRoutes.profile,
      UserProfile.companion => AppRoutes.pin,
      _ => AppRoutes.scanner,
    };
  }

  static Future<void> changeProfile() async {
    final settings = Get.find<ISettingsRepository>();
    final current = await settings.load();
    await settings.save(current.copyWith(clearProfile: true));
    Get.find<ThemeController>().profile.value = null;
    go(AppRoutes.profile);
  }

  /// Borrado total (HU14, CA2): datos, PIN y clave; luego se abre de nuevo
  /// el almacenamiento vacío con una clave nueva.
  static Future<void> wipeAllData() async {
    await Get.find<DataWipeService>().wipeAll();
    await AppBindings.reopenStorage();
    Get.find<ThemeController>().profile.value = null;
  }

  static void _putZones() {
    if (Get.isRegistered<ZonesController>()) {
      return;
    }
    Get.lazyPut<ZonesController>(
      () => ZonesController(
        zones: Get.find<IZoneRepository>(),
        service: Get.find<ZoneService>(),
        location: Get.find<ILocationService>(),
        permissions: Get.find<IPermissionGuard>(),
      ),
    );
  }

  static final List<GetPage<dynamic>> pages = [
    GetPage<void>(
      name: AppRoutes.splash,
      page: () => SplashView(
        nextRoute: () => initialRouteFor(Get.find<ISettingsRepository>()),
        navigate: go,
      ),
    ),
    GetPage<void>(
      name: AppRoutes.profile,
      page: () => const ProfileView(),
      binding: BindingsBuilder<void>(() {
        Get.lazyPut<ProfileController>(
          () => ProfileController(
            speech: Get.find<ISpeechService>(),
            voice: Get.find<IVoiceInput>(),
            settings: Get.find<ISettingsRepository>(),
            theme: Get.find<ThemeController>(),
            navigate: go,
          ),
        );
      }),
    ),
    GetPage<void>(
      name: AppRoutes.pin,
      page: () => const PinView(),
      binding: BindingsBuilder<void>(() {
        Get.lazyPut<PinController>(
          () => PinController(
            guard: Get.find<PinGuard>(),
            settings: Get.find<ISettingsRepository>(),
            speech: Get.find<ISpeechService>(),
            theme: Get.find<ThemeController>(),
            navigate: go,
          ),
        );
      }),
    ),
    GetPage<void>(
      name: AppRoutes.scanner,
      page: () => const ScannerView(onChangeProfile: changeProfile),
      binding: BindingsBuilder<void>(() {
        Get.lazyPut<ScannerController>(
          () => ScannerController(
            detector: Get.find<IObstacleDetector>(),
            sources: Get.find<VideoSourceSelector>(),
            speech: Get.find<ISpeechService>(),
            voice: Get.find<IVoiceInput>(),
            haptics: Get.find<IHaptics>(),
            earcons: Get.find<IEarcons>(),
            location: Get.find<ILocationService>(),
            permissions: Get.find<IPermissionGuard>(),
            wakelock: Get.find<IWakelock>(),
            settings: Get.find<ISettingsRepository>(),
            zones: Get.find<IZoneRepository>(),
            history: Get.find<IHistoryRepository>(),
            zoneService: Get.find<ZoneService>(),
          ),
        );
      }),
    ),
    GetPage<void>(
      name: AppRoutes.companion,
      page: () => const CompanionShellView(onChangeProfile: changeProfile),
      binding: BindingsBuilder<void>(() {
        _putZones();
        Get.lazyPut<HistoryController>(
          () => HistoryController(history: Get.find<IHistoryRepository>()),
        );
        Get.lazyPut<SettingsController>(
          () => SettingsController(
            settings: Get.find<ISettingsRepository>(),
            speech: Get.find<ISpeechService>(),
            sources: Get.find<VideoSourceSelector>(),
            haptics: Get.find<IHaptics>(),
            earcons: Get.find<IEarcons>(),
          ),
        );
        Get.lazyPut<PrivacyController>(
          () => PrivacyController(
            zones: Get.find<IZoneRepository>(),
            history: Get.find<IHistoryRepository>(),
            audit: Get.find<IAuditRepository>(),
            permissions: Get.find<IPermissionGuard>(),
            pin: Get.find<PinGuard>(),
            wipe: wipeAllData,
            navigate: go,
            zoneService: Get.find<ZoneService>(),
            exporter: Get.find<IFileExporter>(),
          ),
        );
      }),
    ),
    GetPage<void>(
      name: AppRoutes.editZone,
      page: () => EditZoneView(zoneId: Get.arguments as String),
      binding: BindingsBuilder<void>(_putZones),
    ),
    GetPage<void>(
      name: AppRoutes.testMode,
      page: () => const TestModeView(),
      binding: BindingsBuilder<void>(() {
        Get.lazyPut<TestModeController>(
          () => TestModeController(
            detector: Get.find<IObstacleDetector>(),
            sources: Get.find<VideoSourceSelector>(),
            settings: Get.find<ISettingsRepository>(),
            speech: Get.find<ISpeechService>(),
            haptics: Get.find<IHaptics>(),
            earcons: Get.find<IEarcons>(),
            location: Get.find<ILocationService>(),
            permissions: Get.find<IPermissionGuard>(),
            wakelock: Get.find<IWakelock>(),
            exporter: Get.find<IFileExporter>(),
          ),
        );
      }),
    ),
  ];
}
