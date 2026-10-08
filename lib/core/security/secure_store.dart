import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén de secretos del sistema operativo (diagrama de clases).
///
/// La interfaz permite probar el módulo de seguridad sin el teléfono.
abstract interface class ISecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Implementación con flutter_secure_storage: en Android cifra los valores
/// con una clave del Android Keystore «c:FSS,AKS».
class FlutterSecureStore implements ISecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
