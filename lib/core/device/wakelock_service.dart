import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantiene la pantalla encendida mientras el escáner está activo
/// (HU02, CA4).
abstract interface class IWakelock {
  Future<void> enable();

  Future<void> disable();
}

class WakelockPlusService implements IWakelock {
  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}
