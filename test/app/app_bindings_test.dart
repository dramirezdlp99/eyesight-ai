import 'dart:io';

import 'package:eyesight_ai/core/device/haptics.dart';
import 'package:eyesight_ai/core/device/location_service.dart';
import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/speech_service.dart';
import 'package:eyesight_ai/core/device/voice_input.dart';
import 'package:eyesight_ai/core/security/data_wipe_service.dart';
import 'package:eyesight_ai/core/security/encrypted_storage.dart';
import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/domain/entities/detection_record.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/repositories/i_history_repository.dart';
import 'package:eyesight_ai/domain/repositories/i_settings_repository.dart';
import 'package:eyesight_ai/domain/repositories/i_zone_repository.dart';
import 'package:eyesight_ai/domain/usecases/zone_service.dart';
import 'package:eyesight_ai/presentation/bindings/app_bindings.dart';
import 'package:eyesight_ai/presentation/controllers/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/builders.dart';
import '../support/fakes.dart';

void main() {
  late Directory dir;
  late InMemorySecureStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('eyesight_app_');
    store = InMemorySecureStore();
  });

  tearDown(() async {
    await AppBindings.dispose();
    dir.deleteSync(recursive: true);
  });

  test('registra todas las dependencias con almacenamiento cifrado', () async {
    await AppBindings.init(
        secureStore: store, storageDirectory: dir.path, clock: () => t0);
    expect(Get.find<EncryptedStorage>().isOpen, isTrue);
    expect(Get.isRegistered<IZoneRepository>(), isTrue);
    expect(Get.isRegistered<IHistoryRepository>(), isTrue);
    expect(Get.isRegistered<ISettingsRepository>(), isTrue);
    expect(Get.isRegistered<PinGuard>(), isTrue);
    expect(Get.isRegistered<ZoneService>(), isTrue);
    expect(Get.isRegistered<DataWipeService>(), isTrue);
    expect(store.values.length, 1); // solo la clave AES-256
  });

  test('registra los servicios del teléfono sin crearlos todavía', () async {
    await AppBindings.init(
        secureStore: store, storageDirectory: dir.path, clock: () => t0);
    expect(Get.isRegistered<ISpeechService>(), isTrue);
    expect(Get.isRegistered<IVoiceInput>(), isTrue);
    expect(Get.isRegistered<IHaptics>(), isTrue);
    expect(Get.isRegistered<ILocationService>(), isTrue);
    expect(Get.isRegistered<IPermissionGuard>(), isTrue);
    expect(Get.find<ThemeController>().profile.value, isNull);
  });

  test('al arrancar purga el historial de más de 90 días (HU12, CA4)',
      () async {
    await AppBindings.init(
        secureStore: store, storageDirectory: dir.path, clock: () => t0);
    final history = Get.find<IHistoryRepository>();
    await history.add(
      DetectionRecord(
        label: 'pole',
        confidence: 0.9,
        proximity: Proximity.near,
        timestamp: t0.subtract(const Duration(days: 120)),
      ),
    );
    await history.add(
      DetectionRecord(
        label: 'pole',
        confidence: 0.9,
        proximity: Proximity.near,
        timestamp: t0.subtract(const Duration(days: 5)),
      ),
    );
    await AppBindings.dispose();

    await AppBindings.init(
        secureStore: store, storageDirectory: dir.path, clock: () => t0);
    expect(await Get.find<IHistoryRepository>().count(), 1);
  });
}
