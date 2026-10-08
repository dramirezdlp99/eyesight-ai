import 'package:get/get.dart';

import '../../core/security/data_wipe_service.dart';
import '../../core/security/encrypted_storage.dart';
import '../../core/security/pin_guard.dart';
import '../../core/security/secure_key_service.dart';
import '../../core/security/secure_store.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/zone_repository.dart';
import '../../domain/repositories/i_audit_repository.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../../domain/usecases/purge_old_history.dart';
import '../../domain/usecases/zone_service.dart';

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
