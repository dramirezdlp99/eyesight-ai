import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../config/app_constants.dart';

/// Resumen almacenado del PIN: `iteraciones:sal:resumen` en Base64.
class PinHash {
  const PinHash({
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  /// Lanza [FormatException] si el texto almacenado está dañado.
  factory PinHash.parse(String stored) {
    final parts = stored.split(':');
    if (parts.length != 3) {
      throw const FormatException('Resumen de PIN inválido');
    }
    final iterations = int.tryParse(parts[0]);
    if (iterations == null || iterations < 1) {
      throw const FormatException('Iteraciones de PIN inválidas');
    }
    return PinHash(
      iterations: iterations,
      salt: base64Decode(parts[1]),
      hash: base64Decode(parts[2]),
    );
  }

  final int iterations;
  final List<int> salt;
  final List<int> hash;

  String encode() => '$iterations:${base64Encode(salt)}:${base64Encode(hash)}';
}

/// Resumen del PIN del acompañante con PBKDF2-HMAC-SHA256 y sal aleatoria
/// (RNF10). El PIN nunca se guarda en texto plano.
class PinHasher {
  PinHasher({
    this.iterations = AppConstants.pinHashIterations,
    Random? random,
  }) : _random = random ?? Random.secure();

  final int iterations;
  final Random _random;

  static const int keyLength = 32;

  PinHash hash(String pin) {
    final salt = List<int>.generate(
      AppConstants.pinSaltLength,
      (_) => _random.nextInt(256),
    );
    return PinHash(
      iterations: iterations,
      salt: salt,
      hash: pbkdf2(utf8.encode(pin), salt, iterations, keyLength),
    );
  }

  /// Compara en tiempo constante para no filtrar información por tiempos.
  static bool verify(String pin, PinHash stored) {
    final candidate = pbkdf2(
      utf8.encode(pin),
      stored.salt,
      stored.iterations,
      stored.hash.length,
    );
    return constantTimeEquals(candidate, stored.hash);
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// PBKDF2 con HMAC-SHA256 (RFC 8018).
  static Uint8List pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int length,
  ) {
    if (iterations < 1 || length < 1) {
      throw ArgumentError('Parámetros de PBKDF2 inválidos');
    }
    final hmac = Hmac(sha256, password);
    final result = Uint8List(length);
    var offset = 0;
    var blockIndex = 1;
    while (offset < length) {
      final block = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (blockIndex >> 24) & 0xff
        ..[salt.length + 1] = (blockIndex >> 16) & 0xff
        ..[salt.length + 2] = (blockIndex >> 8) & 0xff
        ..[salt.length + 3] = blockIndex & 0xff;
      var u = hmac.convert(block).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final take = (length - offset) < t.length ? length - offset : t.length;
      result.setRange(offset, offset + take, t);
      offset += take;
      blockIndex++;
    }
    return result;
  }
}
