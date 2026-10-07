import '../config/app_constants.dart';

/// Estado de los intentos de PIN, persistido en el almacenamiento seguro.
class PinLockState {
  const PinLockState({this.failedAttempts = 0, this.lockedUntil});

  factory PinLockState.fromMap(Map<dynamic, dynamic> map) {
    final attempts = map['failedAttempts'];
    final until = map['lockedUntil'];
    return PinLockState(
      failedAttempts: attempts is int && attempts >= 0 ? attempts : 0,
      lockedUntil:
          until is int ? DateTime.fromMillisecondsSinceEpoch(until) : null,
    );
  }

  final int failedAttempts;
  final DateTime? lockedUntil;

  Map<String, Object?> toMap() => {
        'failedAttempts': failedAttempts,
        'lockedUntil': lockedUntil?.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is PinLockState &&
      other.failedAttempts == failedAttempts &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode => Object.hash(failedAttempts, lockedUntil);
}

/// Bloqueo de 60 s tras 5 intentos fallidos (RNF10, control de suplantación).
class PinLockoutPolicy {
  const PinLockoutPolicy({
    this.maxAttempts = AppConstants.maxPinAttempts,
    this.lockDuration = AppConstants.pinLockDuration,
  });

  final int maxAttempts;
  final Duration lockDuration;

  bool isLocked(PinLockState state, DateTime now) {
    final until = state.lockedUntil;
    return until != null && now.isBefore(until);
  }

  /// Tiempo restante de bloqueo; cero si no está bloqueado.
  Duration remaining(PinLockState state, DateTime now) {
    final until = state.lockedUntil;
    if (until == null || !now.isBefore(until)) {
      return Duration.zero;
    }
    return until.difference(now);
  }

  PinLockState registerFailure(PinLockState state, DateTime now) {
    // Si un bloqueo anterior ya venció, se empieza a contar de nuevo.
    final base = (state.lockedUntil != null && !isLocked(state, now))
        ? const PinLockState()
        : state;
    final attempts = base.failedAttempts + 1;
    if (attempts >= maxAttempts) {
      return PinLockState(
        failedAttempts: attempts,
        lockedUntil: now.add(lockDuration),
      );
    }
    return PinLockState(failedAttempts: attempts);
  }

  PinLockState registerSuccess() => const PinLockState();
}
