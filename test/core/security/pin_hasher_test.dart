import 'dart:convert';
import 'dart:math';

import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256 (vectores de referencia)', () {
    final p = utf8.encode('password');
    final s = utf8.encode('salt');

    test('c = 1', () {
      expect(
        hex(PinHasher.pbkdf2(p, s, 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('c = 2', () {
      expect(
        hex(PinHasher.pbkdf2(p, s, 2, 32)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('c = 4096', () {
      expect(
        hex(PinHasher.pbkdf2(p, s, 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('clave de 40 bytes (más de un bloque)', () {
      expect(
        hex(
          PinHasher.pbkdf2(
            utf8.encode('passwordPASSWORDpassword'),
            utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
            4096,
            40,
          ),
        ),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9',
      );
    });

    test('parámetros inválidos', () {
      expect(() => PinHasher.pbkdf2(p, s, 0, 32), throwsArgumentError);
    });
  });

  group('PinHasher', () {
    final hasher = PinHasher(iterations: 1000, random: Random(42));

    test('el PIN correcto se verifica y uno incorrecto no', () {
      final h = hasher.hash('2468');
      expect(PinHasher.verify('2468', h), isTrue);
      expect(PinHasher.verify('2469', h), isFalse);
    });

    test('el resumen no contiene el PIN en texto plano', () {
      final stored = hasher.hash('2468').encode();
      expect(stored.contains('2468'), isFalse);
      expect(stored.split(':').length, 3);
    });

    test('dos resúmenes del mismo PIN usan sales distintas', () {
      final a = hasher.hash('2468');
      final b = hasher.hash('2468');
      expect(a.salt, isNot(equals(b.salt)));
      expect(a.hash, isNot(equals(b.hash)));
    });

    test('ida y vuelta por texto almacenado', () {
      final h = hasher.hash('135790');
      final back = PinHash.parse(h.encode());
      expect(back.iterations, 1000);
      expect(PinHasher.verify('135790', back), isTrue);
    });

    test('texto almacenado dañado lanza FormatException', () {
      expect(() => PinHash.parse('basura'), throwsFormatException);
      expect(() => PinHash.parse('x:AA==:AA=='), throwsFormatException);
    });

    test('comparación en tiempo constante', () {
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(PinHasher.constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });
}
