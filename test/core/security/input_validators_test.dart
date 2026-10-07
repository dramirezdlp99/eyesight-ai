import 'package:eyesight_ai/core/security/input_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radio de 5 a 100 m (HU11, CA2)', () {
    expect(InputValidators.radius(5), isNull);
    expect(InputValidators.radius(100), isNull);
    expect(InputValidators.radius(4.9), isNotNull);
    expect(InputValidators.radius(101), isNotNull);
    expect(InputValidators.radius(null), isNotNull);
    expect(InputValidators.radius(double.nan), isNotNull);
  });

  test('nota de hasta 100 caracteres', () {
    expect(InputValidators.note('a' * 100), isNull);
    expect(InputValidators.note('a' * 101), isNotNull);
  });

  test('umbral de confianza de 0,30 a 0,90 (HU13, CA2)', () {
    expect(InputValidators.confidence(0.3), isNull);
    expect(InputValidators.confidence(0.9), isNull);
    expect(InputValidators.confidence(0.29), isNotNull);
    expect(InputValidators.confidence(0.95), isNotNull);
  });

  test('velocidad de voz de 0,5x a 2,0x', () {
    expect(InputValidators.speechRate(1), isNull);
    expect(InputValidators.speechRate(2.5), isNotNull);
  });

  test('PIN de 4 a 6 dígitos (RF02)', () {
    expect(InputValidators.pin('1234'), isNull);
    expect(InputValidators.pin('123456'), isNull);
    expect(InputValidators.pin('123'), isNotNull);
    expect(InputValidators.pin('1234567'), isNotNull);
    expect(InputValidators.pin('12a4'), isNotNull);
    expect(InputValidators.pin(' 1234'), isNotNull);
  });

  test('coordenadas en rango válido', () {
    expect(InputValidators.coordinates(1.2136, -77.2811), isTrue);
    expect(InputValidators.coordinates(91, 0), isFalse);
    expect(InputValidators.coordinates(0, -181), isFalse);
    expect(InputValidators.coordinates(double.nan, 0), isFalse);
  });

  test('sanitizeNote elimina caracteres de control y recorta', () {
    expect(InputValidators.sanitizeNote('  Frente\n a la\ttienda  '),
        'Frente a la tienda');
    expect(InputValidators.sanitizeNote('x' * 150).length, 100);
  });

  test('confirmación de borrado exige escribir ELIMINAR (HU14, CA2)', () {
    expect(InputValidators.wipeConfirmation('ELIMINAR'), isTrue);
    expect(InputValidators.wipeConfirmation(' ELIMINAR '), isTrue);
    expect(InputValidators.wipeConfirmation('eliminar'), isFalse);
  });
}
