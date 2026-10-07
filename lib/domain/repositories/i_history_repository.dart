import '../entities/detection_record.dart';

/// Puerto del historial de detecciones (RF17).
abstract interface class IHistoryRepository {
  Future<void> add(DetectionRecord record);

  /// Registros del más reciente al más antiguo (HU12, CA1), filtrados por
  /// rango de fechas y tipo (HU12, CA2).
  Future<List<DetectionRecord>> query({
    DateTime? from,
    DateTime? to,
    String? label,
  });

  /// Elimina los registros anteriores a [cutoff] y devuelve cuántos borró.
  Future<int> purgeOlderThan(DateTime cutoff);

  Future<int> count();

  Future<void> clear();
}
