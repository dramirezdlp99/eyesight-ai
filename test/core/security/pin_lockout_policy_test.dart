import 'package:eyesight_ai/core/security/pin_lockout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = PinLockoutPolicy();
  final t0 = DateTime(2026, 10, 7, 9);

  test('bloquea 60 s al quinto intento fallido (RNF10)', () {
    var s = const PinLockState();
    for (var i = 0; i < 4; i++) {
      s = policy.registerFailure(s, t0);
      expect(policy.isLocked(s, t0), isFalse);
    }
    s = policy.registerFailure(s, t0);
    expect(policy.isLocked(s, t0), isTrue);
    expect(policy.remaining(s, t0), const Duration(seconds: 60));
    expect(policy.isLocked(s, t0.add(const Duration(seconds: 59))), isTrue);
    expect(policy.isLocked(s, t0.add(const Duration(seconds: 60))), isFalse);
  });

  test('tras vencer el bloqueo, la cuenta empieza de nuevo', () {
    var s = PinLockState(failedAttempts: 5, lockedUntil: t0);
    s = policy.registerFailure(s, t0.add(const Duration(seconds: 1)));
    expect(s.failedAttempts, 1);
    expect(s.lockedUntil, isNull);
  });

  test('un acierto reinicia el estado', () {
    expect(policy.registerSuccess(), const PinLockState());
  });

  test('ida y vuelta por mapa y tolerancia a datos dañados', () {
    final s = PinLockState(failedAttempts: 3, lockedUntil: t0);
    expect(PinLockState.fromMap(s.toMap()), s);
    expect(PinLockState.fromMap({'failedAttempts': -1, 'lockedUntil': 'x'}),
        const PinLockState());
  });
}
