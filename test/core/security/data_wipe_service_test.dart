import 'dart:io';

import 'package:eyesight_ai/core/security/data_wipe_service.dart';
import 'package:eyesight_ai/core/security/encrypted_storage.dart';
import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:eyesight_ai/core/security/secure_key_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../support/fakes.dart';

void main() {
  test('borra colecciones, clave de cifrado y PIN (HU14, CA2)', () async {
    final dir = Directory.systemTemp.createTempSync('eyesight_wipe_');
    final store = InMemorySecureStore();
    final keys = SecureKeyService(store);
    final storage = await EncryptedStorage.open(
      key: await keys.getOrCreateKey(),
      directory: dir.path,
    );
    final hasher = PinHasher(iterations: 500);
    final pin = PinGuard(
      store,
      hash: (p) async => hasher.hash(p),
      verify: (p, h) async => PinHasher.verify(p, h),
    );
    await pin.setPin('2468');
    await storage.box(EncryptedStorage.zonesBox).put('z1', {'type': 'pothole'});

    await DataWipeService(storage: storage, keys: keys, pin: pin).wipeAll();

    expect(store.values, isEmpty);
    expect(await pin.hasPin(), isFalse);
    final hiveFiles =
        dir.listSync().whereType<File>().where((f) => f.path.endsWith('.hive'));
    expect(hiveFiles, isEmpty);

    // Al volver a abrir se crea una clave nueva y la memoria está vacía.
    final fresh = await EncryptedStorage.open(
      key: await keys.getOrCreateKey(),
      directory: dir.path,
    );
    expect(fresh.box(EncryptedStorage.zonesBox).isEmpty, isTrue);

    await Hive.close();
    dir.deleteSync(recursive: true);
  });
}
