import 'package:hive_flutter/hive_flutter.dart';

/// Colecciones de Hive cifradas con AES-256 (numerales 3.12.6 y 4.3.7).
///
/// Sin la clave, los archivos de datos no son legibles. Hive cifra los
/// valores; las claves de cada registro son identificadores aleatorios o
/// números, sin datos personales.
class EncryptedStorage {
  EncryptedStorage._(this._boxes);

  static const String zonesBox = 'zones';
  static const String historyBox = 'history';
  static const String settingsBox = 'settings';
  static const String auditBox = 'audit';
  static const List<String> boxNames = [
    zonesBox,
    historyBox,
    settingsBox,
    auditBox,
  ];

  /// Subcarpeta de los datos dentro del almacenamiento privado de la app.
  static const String subDirectory = 'eyesight_data';

  final Map<String, Box<dynamic>> _boxes;

  /// Abre todas las colecciones con [key] (32 bytes). En las pruebas se pasa
  /// [directory]; en el teléfono se usa el almacenamiento privado de la app.
  static Future<EncryptedStorage> open({
    required List<int> key,
    String? directory,
  }) async {
    if (key.length != 32) {
      throw ArgumentError('La clave AES-256 debe tener 32 bytes');
    }
    if (directory != null) {
      Hive.init(directory);
    } else {
      await Hive.initFlutter(subDirectory);
    }
    final cipher = HiveAesCipher(key);
    final boxes = <String, Box<dynamic>>{};
    for (final name in boxNames) {
      boxes[name] = await Hive.openBox<dynamic>(
        name,
        encryptionCipher: cipher,
      );
    }
    return EncryptedStorage._(boxes);
  }

  Box<dynamic> box(String name) {
    final box = _boxes[name];
    if (box == null || !box.isOpen) {
      throw StateError('La colección $name no está abierta');
    }
    return box;
  }

  bool get isOpen => _boxes.isNotEmpty && _boxes.values.every((b) => b.isOpen);

  Future<void> close() async {
    for (final box in _boxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
  }

  /// Borra del disco todas las colecciones (HU14, CA2).
  Future<void> deleteAll() async {
    for (final box in _boxes.values) {
      await box.deleteFromDisk();
    }
    _boxes.clear();
  }
}
