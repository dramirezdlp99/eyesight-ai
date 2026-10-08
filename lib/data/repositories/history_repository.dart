import 'package:hive_flutter/hive_flutter.dart';

import '../../core/ai/obstacle_catalog.dart';
import '../../domain/entities/detection_record.dart';
import '../../domain/repositories/i_history_repository.dart';

/// Historial de detecciones en Hive cifrado (RF17, HU12).
class HistoryRepository implements IHistoryRepository {
  HistoryRepository(this._box);

  final Box<dynamic> _box;

  @override
  Future<void> add(DetectionRecord record) async {
    await _box.add(record.toMap());
  }

  @override
  Future<List<DetectionRecord>> query({
    DateTime? from,
    DateTime? to,
    String? label,
  }) async {
    final wanted = label == null ? null : ObstacleCatalog.normalize(label);
    final result = <DetectionRecord>[];
    for (final raw in _box.values) {
      final record = _decode(raw);
      if (record == null) {
        continue;
      }
      if (from != null && record.timestamp.isBefore(from)) {
        continue;
      }
      if (to != null && record.timestamp.isAfter(to)) {
        continue;
      }
      if (wanted != null && ObstacleCatalog.normalize(record.label) != wanted) {
        continue;
      }
      result.add(record);
    }
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  @override
  Future<int> purgeOlderThan(DateTime cutoff) async {
    final old = <dynamic>[];
    for (final key in _box.keys) {
      final record = _decode(_box.get(key));
      // Los registros dañados también se eliminan.
      if (record == null || record.timestamp.isBefore(cutoff)) {
        old.add(key);
      }
    }
    await _box.deleteAll(old);
    return old.length;
  }

  @override
  Future<int> count() async => _box.length;

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  static DetectionRecord? _decode(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      return DetectionRecord.fromMap(raw);
    } on FormatException {
      return null;
    }
  }
}
