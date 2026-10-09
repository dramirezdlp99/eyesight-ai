import 'package:get/get.dart';

import '../../core/ai/i_obstacle_detector.dart';
import '../../core/device/haptics.dart';
import '../../core/device/location_service.dart';
import '../../core/device/permission_guard.dart';
import '../../core/device/speech_service.dart';
import '../../core/device/video_source_selector.dart';
import '../../core/device/voice_input.dart';
import '../../core/device/wakelock_service.dart';
import '../../core/security/pin_guard.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../../domain/usecases/zone_service.dart';
import '../controllers/pin_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/scanner_controller.dart';
import '../controllers/theme_controller.dart';
import '../views/companion/companion_home_view.dart';
import '../views/debug/detection_debug_view.dart';
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
      page: () => const CompanionHomeView(onChangeProfile: changeProfile),
    ),
    GetPage<void>(
      name: AppRoutes.detectionTest,
      page: () => const DetectionDebugView(),
    ),
  ];
}
