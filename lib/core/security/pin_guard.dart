import 'dart:convert';
import 'dart:isolate';

import 'input_validators.dart';
import 'pin_hasher.dart';
import 'pin_lockout_policy.dart';
import 'secure_store.dart';

/// Resultado de verificar el PIN del acompañante.
sealed class PinCheck {
  const PinCheck();
}

final class PinAccepted extends PinCheck {
  const PinAccepted();
}

final class PinRejected extends PinCheck {
  const PinRejected(this.remainingAttempts);

  /// Intentos que quedan antes del bloqueo.
  final int remainingAttempts;
}

final class PinLocked extends PinCheck {
  const PinLocked(this.remaining);

  final Duration remaining;
}

final class PinNotSet extends PinCheck {
  const PinNotSet();
}

typedef PinHashFunction = Future<PinHash> Function(String pin);
typedef PinVerifyFunction = Future<bool> Function(String pin, PinHash hash);

/// Protege el perfil de acompañante y el modo de pruebas (RF02, RNF10).
///
/// El PIN se guarda como resumen PBKDF2 con sal en el almacenamiento seguro,
/// junto con el estado de intentos fallidos, para que reiniciar la app no
/// anule el bloqueo. El cálculo del resumen corre en un hilo aislado para no
/// congelar la interfaz.
class PinGuard {
  PinGuard(
    this._store, {
    PinHashFunction? hash,
    PinVerifyFunction? verify,
    DateTime Function()? clock,
    this.policy = const PinLockoutPolicy(),
  })  : _hash = hash ?? _isolateHash,
        _verify = verify ?? _isolateVerify,
        _clock = clock ?? DateTime.now;

  static const String hashKey = 'eyesight.pin.hash';
  static const String lockKey = 'eyesight.pin.lock';

  final ISecureStore _store;
  final PinHashFunction _hash;
  final PinVerifyFunction _verify;
  final DateTime Function() _clock;
  final PinLockoutPolicy policy;

  Future<bool> hasPin() async => (await _store.read(hashKey)) != null;

  /// Crea o reemplaza el PIN. Lanza [ArgumentError] si no tiene 4 a 6 dígitos.
  Future<void> setPin(String pin) async {
    final error = InputValidators.pin(pin);
    if (error != null) {
      throw ArgumentError(error);
    }
    final hash = await _hash(pin);
    await _store.write(hashKey, hash.encode());
    await _saveLock(const PinLockState());
  }

  Future<PinCheck> verify(String pin) async {
    final stored = await _store.read(hashKey);
    if (stored == null) {
      return const PinNotSet();
    }
    final now = _clock();
    final lock = await _loadLock();
    if (policy.isLocked(lock, now)) {
      return PinLocked(policy.remaining(lock, now));
    }
    final PinHash hash;
    try {
      hash = PinHash.parse(stored);
    } on FormatException {
      return const PinNotSet();
    }
    if (await _verify(pin, hash)) {
      await _saveLock(policy.registerSuccess());
      return const PinAccepted();
    }
    final next = policy.registerFailure(lock, now);
    await _saveLock(next);
    if (policy.isLocked(next, now)) {
      return PinLocked(policy.remaining(next, now));
    }
    return PinRejected(policy.maxAttempts - next.failedAttempts);
  }

  /// Cambia el PIN si [current] es correcto (HU14, CA3).
  Future<PinCheck> changePin(String current, String next) async {
    final error = InputValidators.pin(next);
    if (error != null) {
      throw ArgumentError(error);
    }
    final result = await verify(current);
    if (result is PinAccepted) {
      await setPin(next);
    }
    return result;
  }

  /// Elimina el PIN y el estado de intentos (borrado total, HU14).
  Future<void> clear() async {
    await _store.delete(hashKey);
    await _store.delete(lockKey);
  }

  Future<PinLockState> _loadLock() async {
    final raw = await _store.read(lockKey);
    if (raw == null) {
      return const PinLockState();
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? PinLockState.fromMap(decoded)
          : const PinLockState();
    } on FormatException {
      return const PinLockState();
    }
  }

  Future<void> _saveLock(PinLockState state) =>
      _store.write(lockKey, jsonEncode(state.toMap()));

  static Future<PinHash> _isolateHash(String pin) =>
      Isolate.run(() => PinHasher().hash(pin));

  static Future<bool> _isolateVerify(String pin, PinHash hash) =>
      Isolate.run(() => PinHasher.verify(pin, hash));
}
