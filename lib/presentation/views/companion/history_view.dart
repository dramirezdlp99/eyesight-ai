import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ai/obstacle_catalog.dart';
import '../../../domain/entities/detection_record.dart';
import '../../../domain/entities/proximity.dart';
import '../../controllers/history_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/companion_ui.dart';

/// Historial de alertas con filtros de fecha y tipo (HU12, RF17).
class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  static const List<String> weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const List<String> weekdayNames = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const List<String> months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String two(int v) => v.toString().padLeft(2, '0');

  static String time(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

  /// «Hoy, martes 13 de octubre».
  static String dayTitle(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final diff = today.difference(d).inDays;
    final name =
        '${weekdayNames[d.weekday - 1]} ${d.day} de ${months[d.month - 1]}';
    if (diff == 0) {
      return 'Hoy, $name';
    }
    if (diff == 1) {
      return 'Ayer, $name';
    }
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  static String proximityName(Proximity p) => switch (p) {
        Proximity.near => 'Cerca',
        Proximity.medium => 'Media',
        Proximity.far => 'Lejos',
      };

  Future<void> _clear(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: '¿Borrar todo el historial?',
      body: 'Se eliminan todas las alertas guardadas. Las zonas de riesgo se '
          'conservan.',
      confirmLabel: 'Borrar historial',
    );
    if (ok) {
      await controller.clearAll();
      if (context.mounted) {
        showNotice(context, 'Historial borrado.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final records = controller.records.toList();
      final range = controller.range.value;
      final label = controller.label.value;
      final labels = controller.labels.toList();
      final week = controller.lastWeek.toList();
      final now = controller.now;
      final children = <Widget>[];
      DateTime? lastDay;
      for (final r in records) {
        final day =
            DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        if (lastDay == null || day != lastDay) {
          lastDay = day;
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Semantics(
                header: true,
                child: Text(dayTitle(day, now), style: text.titleMedium),
              ),
            ),
          );
        }
        children.add(_RecordTile(record: r));
      }
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            CompanionHeader(
              title: 'Historial',
              color: AppColors.cobalt,
              stepColor: AppColors.cobaltDeep,
              bottom: _WeekChart(counts: week, now: now),
              trailing: IconButton(
                tooltip: 'Borrar historial',
                icon: const Icon(Icons.delete_sweep_outlined,
                    color: AppColors.paper),
                onPressed: () => _clear(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in HistoryRange.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: r == range,
                      onSelected: (_) => controller.setRange(r),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String?>(
                key: ValueKey('tipo-$label-${labels.length}'),
                initialValue: labels.contains(label) ? label : null,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Tipo de obstáculo'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos los tipos'),
                  ),
                  for (final l in labels)
                    DropdownMenuItem<String?>(
                      value: l,
                      child: Text(ObstacleCatalog.spanishName(l)),
                    ),
                ],
                onChanged: controller.setLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '${records.length} '
                  '${records.length == 1 ? 'alerta' : 'alertas'} · '
                  '${range.label.toLowerCase()}',
                  style: AppText.display(26, color: scheme.onSurface),
                ),
              ),
            ),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Text(
                  'No hay alertas con estos filtros.',
                  style: text.bodyLarge,
                ),
              ),
            ...children,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Row(
                children: [
                  Icon(Icons.auto_delete_outlined,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se conservan 90 días y luego se borran solos.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Barras con las alertas de cada uno de los últimos 7 días.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.counts, required this.now});

  final List<int> counts;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = counts.fold<int>(0, (a, b) => a + b);
    final max = counts.fold<int>(1, (a, b) => b > a ? b : a);
    final today = DateTime(now.year, now.month, now.day);
    return Semantics(
      label: '$total alertas en los últimos 7 días',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total',
            style: AppText.display(40, color: AppColors.paper),
          ),
          Text(
            'alertas en 7 días',
            style: text.bodyMedium?.copyWith(color: AppColors.paper),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 6 + 58 * counts[i] / max,
                            decoration: BoxDecoration(
                              color: i == 6 ? AppColors.oro : AppColors.paper,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              i == 6
                                  ? 'Hoy'
                                  : HistoryView.weekdays[today
                                          .subtract(Duration(days: 6 - i))
                                          .weekday -
                                      1],
                              style: text.labelLarge?.copyWith(
                                color: AppColors.paper,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final DetectionRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = ObstacleCatalog.spanishName(record.label);
    final prox = HistoryView.proximityName(record.proximity);
    final confidence =
        record.confidence.toStringAsFixed(2).replaceAll('.', ',');
    final color = AppColors.forProximity(record.proximity);
    return Semantics(
      label: '${HistoryView.time(record.timestamp)}. $name, '
          '${record.proximity.spoken}. Confianza $confidence.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  HistoryView.time(record.timestamp),
                  style: text.titleMedium,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleMedium),
                    Text(
                      'Confianza $confidence',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  prox,
                  style: text.labelLarge?.copyWith(
                    color: AppColors.onProximity(record.proximity),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
