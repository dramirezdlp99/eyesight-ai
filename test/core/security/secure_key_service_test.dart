import 'dart:convert';
import 'dart:math';

import 'package:eyesight_ai/core/security/secure_key_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  test('crea una clave de 32 bytes la primera vez y la guarda', () async {
    final store = InMemorySecureStore();
    final key = await SecureKeyService(store).getOrCreateKey();
    expect(key.length, 32);
    expect(base64Decode(store.values[SecureKeyService.storageKey]!), key);
  });

  test('devuelve siempre la misma clave mientras exista', () async {
    final store = InMemorySecureStore();
    final a = await SecureKeyService(store).getOrCreateKey();
    final b = await SecureKeyService(store, random: Random(1)).getOrCreateKey();
    expect(b, a);
  });

  test('si la clave guardada está dañada, crea una nueva válida', () async {
    final store = InMemorySecureStore()
      ..values[SecureKeyService.storageKey] = 'esto no es base64 !!';
    final key = await SecureKeyService(store).getOrCreateKey();
    expect(key.length, 32);
  });

  test('deleteKey elimina la clave del almacén seguro (HU14)', () async {
    final store = InMemorySecureStore();
    final service = SecureKeyService(store);
    await service.getOrCreateKey();
    await service.deleteKey();
    expect(store.values.containsKey(SecureKeyService.storageKey), isFalse);
  });
}
