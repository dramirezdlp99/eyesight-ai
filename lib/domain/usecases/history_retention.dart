import '../../core/config/app_constants.dart';

/// Retención del historial: se eliminan los registros de más de 90 días
/// (HU12, CA4), en línea con el principio de minimización de datos.
abstract final class HistoryRetention {
  static DateTime cutoff(DateTime now) =>
      now.subtract(AppConstants.historyRetention);
}
