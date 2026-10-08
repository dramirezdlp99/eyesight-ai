import '../config/app_constants.dart';

/// Controla el ritmo de análisis: como máximo un cuadro a la vez y no más de
/// 10 por segundo (RNF03). Los cuadros que llegan mientras el modelo trabaja
/// se descartan, para que la alerta siempre corresponda a la imagen más
/// reciente y no se acumule retraso.
class FrameGate {
  FrameGate({this.minInterval = AppConstants.minFrameInterval});

  final Duration minInterval;
  bool _busy = false;
  DateTime? _lastStart;
  int dropped = 0;

  bool get busy => _busy;

  /// `true` si el cuadro debe analizarse; en ese caso queda ocupado hasta
  /// llamar a [release].
  bool tryAcquire(DateTime now) {
    final last = _lastStart;
    if (_busy || (last != null && now.difference(last) < minInterval)) {
      dropped++;
      return false;
    }
    _busy = true;
    _lastStart = now;
    return true;
  }

  void release() => _busy = false;

  void reset() {
    _busy = false;
    _lastStart = null;
    dropped = 0;
  }
}
