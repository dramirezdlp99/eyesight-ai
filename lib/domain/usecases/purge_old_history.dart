import '../repositories/i_history_repository.dart';
import 'history_retention.dart';

/// Elimina del historial los registros de más de 90 días al abrir la
/// aplicación (HU12, CA4).
class PurgeOldHistory {
  const PurgeOldHistory(this._history);

  final IHistoryRepository _history;

  Future<int> call(DateTime now) =>
      _history.purgeOlderThan(HistoryRetention.cutoff(now));
}
