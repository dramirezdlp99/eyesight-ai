import 'package:get/get.dart';

import '../../core/ai/i_obstacle_detector.dart';
import '../../core/ai/yolo_litert_detector.dart';
import '../../core/device/haptics.dart';
import '../../core/device/location_service.dart';
import '../../core/device/permission_guard.dart';
import '../../core/device/phone_camera_source.dart';
import '../../core/device/speech_service.dart';
import '../../core/device/usb_camera_source.dart';
import '../../core/device/video_source_selector.dart';
import '../../core/device/voice_input.dart';
import '../../core/device/wakelock_service.dart';
import '../../core/security/data_wipe_service.dart';
import '../../core/security/encrypted_storage.dart';
import '../../core/security/pin_guard.dart';
import '../../core/security/secure_key_service.dart';
import '../../core/security/secure_store.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/zone_repository.dart';
import '../../domain/entities/video_source_kind.dart';
import '../../domain/repositories/i_audit_repository.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../../domain/usecases/purge_old_history.dart';
import '../../domain/usecases/zone_service.dart';
import '../controllers/theme_controller.dart';

/// Crea y registra las dependencias de la aplicación con la inyección de
/// GetX (numeral 3.12.4). Las capas superiores solo conocen las interfaces.
abstract final class AppBindings {
  static Future<void> init({
    ISecureStore? secureStore,
    String? storageDirectory,
    DateTime Function()? clock,
  }) async {
    final now = clock ?? DateTime.now;
    final store = secureStore ?? FlutterSecureStore();
    final keys = SecureKeyService(store);
    final storage = await EncryptedStorage.open(
      key: await keys.getOrCreateKey(),
      directory: storageDirectory,
    );

    final zones = ZoneRepository(storage.box(EncryptedStorage.zonesBox));
    final history = HistoryRepository(storage.box(EncryptedStorage.historyBox));
    final settings =
        SettingsRepository(storage.box(EncryptedStorage.settingsBox));
    final audit = AuditRepository(storage.box(EncryptedStorage.auditBox));
    final pin = PinGuard(store, clock: now);

    Get.put<ISecureStore>(store, permanent: true);
    Get.put<SecureKeyService>(keys, permanent: true);
    Get.put<EncryptedStorage>(storage, permanent: true);
    Get.put<IZoneRepository>(zones, permanent: true);
    Get.put<IHistoryRepository>(history, permanent: true);
    Get.put<ISettingsRepository>(settings, permanent: true);
    Get.put<IAuditRepository>(audit, permanent: true);
    Get.put<PinGuard>(pin, permanent: true);
    Get.put<ZoneService>(
      ZoneService(zones: zones, audit: audit, clock: now),
      permanent: true,
    );
    Get.put<DataWipeService>(
      DataWipeService(storage: storage, keys: keys, pin: pin),
      permanent: true,
    );

    // Servicios del teléfono: se crean al usarse por primera vez, para que
    // las pruebas no necesiten los plugins nativos.
    Get.lazyPut<ISpeechService>(FlutterTtsSpeechService.new, fenix: true);
    Get.lazyPut<IVoiceInput>(SpeechToTextVoiceInput.new, fenix: true);
    Get.lazyPut<IHaptics>(VibrationHaptics.new, fenix: true);
    Get.lazyPut<ILocationService>(GeolocatorLocationService.new, fenix: true);
    Get.lazyPut<IPermissionGuard>(PermissionHandlerGuard.new, fenix: true);
    Get.lazyPut<IWakelock>(WakelockPlusService.new, fenix: true);
    // Detector y fuentes de video del escáner (patrón Strategy, RNF15).
    Get.lazyPut<IObstacleDetector>(YoloLiteRtDetector.new, fenix: true);
    Get.lazyPut<VideoSourceSelector>(
      () => VideoSourceSelector({
        VideoSourceKind.phone: PhoneCameraSource(),
        VideoSourceKind.usb: const UsbCameraSource(),
      }),
      fenix: true,
    );
    Get.put<ThemeController>(ThemeController(), permanent: true);

    // Retención de 90 días del historial (HU12, CA4).
    await PurgeOldHistory(history)(now());
  }

  /// Cierra el almacenamiento y elimina todas las dependencias registradas.
  static Future<void> dispose() async {
    if (Get.isRegistered<EncryptedStorage>()) {
      await Get.find<EncryptedStorage>().close();
    }
    Get.reset();
  }
}
