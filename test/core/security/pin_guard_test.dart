import 'package:eyesight_ai/core/security/pin_guard.dart';
import 'package:eyesight_ai/core/security/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late InMemorySecureStore store;
  late DateTime now;
  late PinGuard guard;

  setUp(() {
    store = InMemorySecureStore();
    now = DateTime(2026, 10, 7, 9);
    final hasher = PinHasher(iterations: 500);
    guard = PinGuard(
      store,
      hash: (pin) async => hasher.hash(pin),
      verify: (pin, hash) async => PinHasher.verify(pin, hash),
      clock: () => now,
    );
  });

  test('sin PIN configurado informa PinNotSet (HU01, CA3)', () async {
    expect(await guard.hasPin(), isFalse);
    expect(await guard.verify('1234'), isA<PinNotSet>());
  });

  test('el PIN se guarda como resumen y no en texto plano', () async {
    await guard.setPin('2468');
    expect(await guard.hasPin(), isTrue);
    final stored = store.values[PinGuard.hashKey]!;
    expect(stored.contains('2468'), isFalse);
  });

  test('rechaza PIN con formato inválido', () async {
    await expectLater(guard.setPin('12'), throwsArgumentError);
    await expectLater(guard.setPin('abcd'), throwsArgumentError);
  });

  test('PIN correcto se acepta y uno incorrecto informa intentos restantes',
      () async {
    await guard.setPin('2468');
    expect(await guard.verify('2468'), isA<PinAccepted>());
    final r = await guard.verify('1111');
    expect((r as PinRejected).remainingAttempts, 4);
  });

  test('cinco fallos bloquean 60 s, incluso con el PIN correcto (RNF10)',
      () async {
    await guard.setPin('2468');
    for (var i = 0; i < 4; i++) {
      expect(await guard.verify('0000'), isA<PinRejected>());
    }
    final fifth = await guard.verify('0000');
    expect((fifth as PinLocked).remaining, const Duration(seconds: 60));
    expect(await guard.verify('2468'), isA<PinLocked>());

    now = now.add(const Duration(seconds: 61));
    expect(await guard.verify('2468'), isA<PinAccepted>());
  });

  test('el bloqueo persiste aunque se cree otro PinGuard (reinicio de la app)',
      () async {
    await guard.setPin('2468');
    for (var i = 0; i < 5; i++) {
      await guard.verify('0000');
    }
    final hasher = PinHasher(iterations: 500);
    final again = PinGuard(
      store,
      hash: (pin) async => hasher.hash(pin),
      verify: (pin, hash) async => PinHasher.verify(pin, hash),
      clock: () => now,
    );
    expect(await again.verify('2468'), isA<PinLocked>());
  });

  test('un acierto reinicia el contador de fallos', () async {
    await guard.setPin('2468');
    await guard.verify('0000');
    await guard.verify('0000');
    await guard.verify('2468');
    final r = await guard.verify('0000');
    expect((r as PinRejected).remainingAttempts, 4);
  });

  test('cambiar PIN exige el actual (HU14, CA3)', () async {
    await guard.setPin('2468');
    expect(await guard.changePin('9999', '1357'), isA<PinRejected>());
    expect(await guard.verify('2468'), isA<PinAccepted>());
    expect(await guard.changePin('2468', '1357'), isA<PinAccepted>());
    expect(await guard.verify('1357'), isA<PinAccepted>());
    expect(await guard.verify('2468'), isA<PinRejected>());
  });

  test('clear elimina el PIN y el estado de intentos', () async {
    await guard.setPin('2468');
    await guard.verify('0000');
    await guard.clear();
    expect(store.values, isEmpty);
  });

  test('un estado de bloqueo dañado no impide verificar', () async {
    await guard.setPin('2468');
    store.values[PinGuard.lockKey] = '{no es json';
    expect(await guard.verify('2468'), isA<PinAccepted>());
  });
}
