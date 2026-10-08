import 'encrypted_storage.dart';
import 'pin_guard.dart';
import 'secure_key_service.dart';

/// Borrado definitivo de los datos del teléfono (HU14, RF20).
///
/// Elimina las colecciones de Hive, la clave de cifrado y el PIN. Después del
/// borrado la aplicación vuelve a la selección de perfil y crea una clave
/// nueva al abrir de nuevo el almacenamiento.
class DataWipeService {
  const DataWipeService({
    required this.storage,
    required this.keys,
    required this.pin,
  });

  final EncryptedStorage storage;
  final SecureKeyService keys;
  final PinGuard pin;

  Future<void> wipeAll() async {
    await storage.deleteAll();
    await keys.deleteKey();
    await pin.clear();
  }
}
