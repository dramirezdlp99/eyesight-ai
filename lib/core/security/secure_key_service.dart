import 'dart:convert';
import 'dart:math';

import 'secure_store.dart';

/// Genera y resguarda la clave AES-256 de la base de datos local
/// (módulo de seguridad, numeral 4.3.7).
///
/// La clave se crea con un generador criptográfico en el primer uso y se
/// guarda en el almacenamiento seguro, respaldado por el Android Keystore.
/// Nunca se escribe en el código ni en archivos del proyecto.
class SecureKeyService {
  SecureKeyService(this._store, {Random? random})
      : _random = random ?? Random.secure();

  static const String storageKey = 'eyesight.hive.aes256';
  static const int keyLength = 32;

  final ISecureStore _store;
  final Random _random;

  Future<List<int>> getOrCreateKey() async {
    final existing = await _store.read(storageKey);
    final decoded = existing == null ? null : _tryDecode(existing);
    if (decoded != null && decoded.length == keyLength) {
      return decoded;
    }
    final key = List<int>.generate(keyLength, (_) => _random.nextInt(256));
    await _store.write(storageKey, base64Encode(key));
    return key;
  }

  /// Elimina la clave: los datos cifrados quedan ilegibles (HU14, CA2).
  Future<void> deleteKey() => _store.delete(storageKey);

  static List<int>? _tryDecode(String value) {
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }
}
