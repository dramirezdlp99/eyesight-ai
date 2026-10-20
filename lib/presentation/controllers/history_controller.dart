import 'package:get/get.dart';

import '../../domain/entities/detection_record.dart';
import '../../domain/repositories/i_history_repository.dart';

/// Rango de fechas del historial (HU12, CA2).
enum HistoryRange {
  today('Hoy'),
  week('7 días'),
  month('30 días'),
  all('Todo');

  const HistoryRange(this.label);

  final String label;

  /// Inicio del rango; `null` para todo el historial.
  DateTime? start(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      HistoryRange.today => today,
      HistoryRange.week => today.subtract(const Duration(days: 6)),
      HistoryRange.month => today.subtract(const Duration(days: 29)),
      HistoryRange.all => null,
    };
  }
}

/// Historial de detecciones con filtros de fecha y tipo (HU12, RF17).
class HistoryController extends GetxController {
  HistoryController({
    required IHistoryRepository history,
    DateTime Function()? clock,
  })  : _history = history,
        _clock = clock ?? DateTime.now;

  final IHistoryRepository _history;
  final DateTime Function() _clock;

  final Rx<HistoryRange> range = HistoryRange.week.obs;

  /// Tipo elegido (clave del modelo); `null` = todos.
  final RxnString label = RxnString();
  final RxList<DetectionRecord> records = <DetectionRecord>[].obs;

  /// Alertas de los últimos 7 días, de hace 6 días a hoy (gráfica).
  final RxList<int> lastWeek = List<int>.filled(7, 0, growable: true).obs;

  /// Tipos presentes en el historial, para el filtro.
  final RxList<String> labels = <String>[].obs;
  final RxBool loading = true.obs;

  DateTime get now => _clock();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    final now = _clock();
    // CA1: de la más reciente a la más antigua; CA2: ambos filtros a la vez.
    final found = await _history.query(
      from: range.value.start(now),
      to: now,
      label: label.value,
    );
    found.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    records.assignAll(found);

    final week = await _history.query(
      from: HistoryRange.week.start(now),
      to: now,
    );
    final today = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(7, 0);
    final types = <String>{};
    for (final r in week) {
      final day =
          DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
      final index = 6 - today.difference(day).inDays;
      if (index >= 0 && index < 7) {
        counts[index]++;
      }
    }
    for (final r in await _history.query()) {
      types.add(r.label);
    }
    lastWeek.assignAll(counts);
    labels.assignAll(types.toList()..sort());
    loading.value = false;
  }

  Future<void> setRange(HistoryRange value) async {
    range.value = value;
    await load();
  }

  Future<void> setLabel(String? value) async {
    label.value = value;
    await load();
  }

  /// Borra todo el historial (HU12, CA3).
  Future<void> clearAll() async {
    await _history.clear();
    label.value = null;
    await load();
  }
}
