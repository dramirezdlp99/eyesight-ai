import 'dart:io';

import 'package:eyesight_ai/core/security/encrypted_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Clave de prueba de 32 bytes (nunca se usa en la aplicación).
final List<int> testKey = List<int>.generate(32, (i) => i * 7 % 256);

/// Almacenamiento cifrado real en una carpeta temporal.
class HiveTestStorage {
  HiveTestStorage._(this.directory, this.storage);

  final Directory directory;
  final EncryptedStorage storage;

  static Future<HiveTestStorage> open(
      {List<int>? key, Directory? directory}) async {
    final dir =
        directory ?? Directory.systemTemp.createTempSync('eyesight_test_');
    final storage =
        await EncryptedStorage.open(key: key ?? testKey, directory: dir.path);
    return HiveTestStorage._(dir, storage);
  }

  Future<void> dispose() async {
    await Hive.close();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}
