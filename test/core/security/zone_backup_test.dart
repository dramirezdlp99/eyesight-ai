import 'dart:convert';

import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:eyesight_ai/core/security/zone_backup.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  ZoneBackup backup() => ZoneBackup(
        iterations: 1000,
        derive: (p, s, it) async => PinHasher.pbkdf2(p, s, it, 64),
      );

  final zones = [
    zone(id: 'a', note: 'Hueco frente a la tienda'),
    zone(id: 'b', type: 'step', origin: ZoneOrigin.manual, radius: 35),
  ];

  test('cifra y recupera las zonas con la misma contraseña', () async {
    final text = await backup().seal(zones, 'clave-segura');
    expect(text, startsWith('${ZoneBackup.header}\n'));
    expect(text, isNot(contains('tienda')));
    final back = await backup().open('Mira: $text\n¡Saludos!', 'clave-segura');
    expect(back.map((z) => z.id), ['a', 'b']);
    expect(back.first.note, 'Hueco frente a la tienda');
    expect(back.last.radiusM, 35);
    expect(back.last.origin, ZoneOrigin.manual);
  });

  test('cada copia usa una sal distinta', () async {
    final a = await backup().seal(zones, 'clave-segura');
    final b = await backup().seal(zones, 'clave-segura');
    expect(a, isNot(b));
  });

  test('rechaza la contraseña incorrecta', () async {
    final text = await backup().seal(zones, 'clave-segura');
    await expectLater(
      () => backup().open(text, 'otra-clave'),
      throwsA(isA<ZoneBackupException>()),
    );
  });

  test('detecta una copia alterada', () async {
    final text = await backup().seal(zones, 'clave-segura');
    final body = text.split('\n').last;
    final envelope =
        jsonDecode(utf8.decode(base64Url.decode(body))) as Map<String, dynamic>;
    final data = base64Decode(envelope['d'] as String);
    data[20] ^= 0x01;
    envelope['d'] = base64Encode(data);
    final tampered =
        '${ZoneBackup.header}\n${base64Url.encode(utf8.encode(jsonEncode(envelope)))}';
    await expectLater(
      () => backup().open(tampered, 'clave-segura'),
      throwsA(
        isA<ZoneBackupException>()
            .having((e) => e.message, 'mensaje', contains('alterada')),
      ),
    );
  });

  test('rechaza textos ajenos o incompletos y contraseñas cortas', () async {
    await expectLater(
      () => backup().open('hola', 'clave-segura'),
      throwsA(isA<ZoneBackupException>()),
    );
    await expectLater(
      () => backup().open('${ZoneBackup.header}\nabc', 'clave-segura'),
      throwsA(isA<ZoneBackupException>()),
    );
    await expectLater(
      () => backup().seal(zones, '123'),
      throwsA(isA<ZoneBackupException>()),
    );
    expect(ZoneBackup.validatePassword('123456'), isNull);
  });
}
