import 'dart:convert';
import 'dart:io';

import 'package:eyesight_ai/core/security/encrypted_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../support/hive_test_storage.dart';

/// `true` si [needle] aparece en los bytes del archivo.
bool fileContains(File file, String needle) {
  final bytes = file.readAsBytesSync();
  final pattern = utf8.encode(needle);
  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    var match = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      return true;
    }
  }
  return false;
}

void main() {
  late HiveTestStorage t;

  setUp(() async => t = await HiveTestStorage.open());
  tearDown(() async => t.dispose());

  test('abre las cuatro colecciones', () {
    for (final name in EncryptedStorage.boxNames) {
      expect(t.storage.box(name).isOpen, isTrue);
    }
    expect(t.storage.isOpen, isTrue);
  });

  test('rechaza claves que no son de 32 bytes', () async {
    await expectLater(
      EncryptedStorage.open(key: [1, 2, 3], directory: t.directory.path),
      throwsArgumentError,
    );
  });

  test('los datos se guardan cifrados en el disco (CP-08, RNF09)', () async {
    const secret = 'Frente a la tienda de Don Jaime';
    await t.storage.box(EncryptedStorage.zonesBox).put('z1', {'note': secret});
    final file = File('${t.directory.path}/zones.hive');
    expect(file.existsSync(), isTrue);
    expect(fileContains(file, secret), isFalse);
    expect(fileContains(file, 'note'), isFalse);
  });

  test('con otra clave los datos no son legibles', () async {
    await t.storage
        .box(EncryptedStorage.zonesBox)
        .put('z1', {'note': 'privado'});
    await Hive.close();
    final otherKey = List<int>.filled(32, 9);
    Object? value;
    try {
      final other = await EncryptedStorage.open(
          key: otherKey, directory: t.directory.path);
      value = other.box(EncryptedStorage.zonesBox).get('z1');
    } on Object {
      value = null;
    }
    expect(value, isNull);
  });

  test('deleteAll borra los archivos del disco (HU14, CA2)', () async {
    await t.storage.box(EncryptedStorage.historyBox).add({'label': 'pole'});
    await t.storage.deleteAll();
    final remaining = t.directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.hive'));
    expect(remaining, isEmpty);
    expect(() => t.storage.box(EncryptedStorage.historyBox), throwsStateError);
  });
}
