import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/risk_zone.dart';
import 'pin_hasher.dart';

/// Error al abrir una copia de zonas: clave incorrecta o texto dañado.
class ZoneBackupException implements Exception {
  const ZoneBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Deriva 64 bytes de clave a partir de la contraseña (PBKDF2-HMAC-SHA256).
typedef KeyDerivation = Future<Uint8List> Function(
  List<int> password,
  List<int> salt,
  int iterations,
);

/// Copia de seguridad cifrada de las zonas de riesgo, sin servidor.
///
/// El acompañante la comparte como texto (WhatsApp, correo, notas) y la
/// pega en otro teléfono para importarla. Así hay respaldo y se pueden
/// pasar las zonas a otra persona sin nube ni cuentas.
///
/// Formato: la línea [header] y un bloque base64 con un JSON que lleva la
/// sal, las iteraciones, los datos cifrados con AES-256-CBC y un HMAC-SHA256
/// (cifrar y luego autenticar). La clave sale de una contraseña que elige
/// el acompañante; sin ella el contenido no se puede leer ni alterar.
class ZoneBackup {
  ZoneBackup({
    this.iterations = defaultIterations,
    KeyDerivation? derive,
    Random? random,
  })  : _derive = derive ?? _isolateDerive,
        _random = random ?? Random.secure();

  static const String header = 'EYESIGHT-ZONAS-1';
  static const int defaultIterations = 100000;
  static const int minPasswordLength = 6;

  final int iterations;
  final KeyDerivation _derive;
  final Random _random;

  static Future<Uint8List> _isolateDerive(
    List<int> password,
    List<int> salt,
    int iterations,
  ) =>
      Isolate.run(() => PinHasher.pbkdf2(password, salt, iterations, 64));

  /// `null` si la contraseña sirve, o el motivo si no.
  static String? validatePassword(String password) =>
      password.length < minPasswordLength
          ? 'La contraseña debe tener al menos $minPasswordLength caracteres.'
          : null;

  /// Cifra las zonas y devuelve el texto para compartir.
  Future<String> seal(List<RiskZone> zones, String password) async {
    final invalid = validatePassword(password);
    if (invalid != null) {
      throw ZoneBackupException(invalid);
    }
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final keys = await _derive(utf8.encode(password), salt, iterations);
    final plain = Uint8List.fromList(
      utf8.encode(jsonEncode([for (final z in zones) z.toMap()])),
    );
    final cipher = HiveAesCipher(keys.sublist(0, 32));
    final out = Uint8List(cipher.maxEncryptedSize(plain));
    final length = cipher.encrypt(plain, 0, plain.length, out, 0);
    final data = out.sublist(0, length);
    final mac = Hmac(sha256, keys.sublist(32)).convert([...salt, ...data]);
    final envelope = jsonEncode({
      'v': 1,
      'it': iterations,
      's': base64Encode(salt),
      'd': base64Encode(data),
      'm': base64Encode(mac.bytes),
    });
    return '$header\n${base64Url.encode(utf8.encode(envelope))}';
  }

  static final RegExp _base64Line = RegExp(r'^[A-Za-z0-9_\-=]+$');

  /// Extrae el sobre JSON del texto que sigue a [header]. El mensaje pegado
  /// puede traer texto antes o después (un saludo en WhatsApp), así que se
  /// toman las líneas seguidas en base64 y se prueba desde la más larga
  /// hasta encontrar un JSON válido. Devuelve `null` si no hay ninguno.
  static Map<String, dynamic>? _envelope(String rest) {
    final lines = <String>[];
    for (final raw in rest.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (lines.isEmpty) {
          continue;
        }
        break;
      }
      if (!_base64Line.hasMatch(line)) {
        break;
      }
      lines.add(line);
    }
    for (var n = lines.length; n > 0; n--) {
      try {
        final decoded =
            jsonDecode(utf8.decode(base64Url.decode(lines.take(n).join())));
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  /// Abre un texto de copia. Lanza [ZoneBackupException] si la contraseña no
  /// es la correcta o el texto está incompleto o alterado.
  Future<List<RiskZone>> open(String text, String password) async {
    final start = text.indexOf(header);
    if (start < 0) {
      throw const ZoneBackupException(
        'El texto no es una copia de zonas de EyeSight AI.',
      );
    }
    final envelope = _envelope(text.substring(start + header.length));
    final List<int> salt;
    final Uint8List data;
    final List<int> mac;
    final int rounds;
    try {
      if (envelope == null) {
        throw const FormatException();
      }
      final it = envelope['it'];
      if (envelope['v'] != 1 || it is! int || it < 1000 || it > 2000000) {
        throw const FormatException();
      }
      rounds = it;
      salt = base64Decode(envelope['s'] as String);
      data = base64Decode(envelope['d'] as String);
      mac = base64Decode(envelope['m'] as String);
    } on Object {
      throw const ZoneBackupException(
        'La copia está incompleta. Copie el texto completo.',
      );
    }
    final keys = await _derive(utf8.encode(password), salt, rounds);
    final expected = Hmac(sha256, keys.sublist(32)).convert([...salt, ...data]);
    if (!PinHasher.constantTimeEquals(expected.bytes, mac)) {
      throw const ZoneBackupException(
        'Contraseña incorrecta o copia alterada.',
      );
    }
    try {
      final out = Uint8List(data.length);
      final length = HiveAesCipher(keys.sublist(0, 32))
          .decrypt(data, 0, data.length, out, 0);
      final list = jsonDecode(utf8.decode(out.sublist(0, length)));
      if (list is! List<dynamic>) {
        throw const FormatException();
      }
      return [
        for (final item in list)
          RiskZone.fromMap(item is Map<dynamic, dynamic> ? item : const {}),
      ];
    } on Object {
      throw const ZoneBackupException('La copia tiene datos inválidos.');
    }
  }
}
