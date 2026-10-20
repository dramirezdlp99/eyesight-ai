import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ai/obstacle_catalog.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/device/phone_camera_source.dart';
import '../../controllers/test_mode_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/companion_ui.dart';
import '../../widgets/detection_overlay.dart';

/// Modo de pruebas del investigador (HU15, RF21): métricas en vivo,
/// etiqueta real y exportación CSV.
class TestModeView extends GetView<TestModeController> {
  const TestModeView({super.key});

  static String mmss(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  static String ms(double v) => v.toStringAsFixed(0);

  static String groundTruthName(String key) =>
      key == 'none' ? 'Ninguno' : ObstacleCatalog.spanishName(key);

  Future<void> _export(BuildContext context) async {
    final path = await controller.exportCsv();
    if (path != null && context.mounted) {
      showNotice(context, 'CSV listo: ${controller.logger.length} cuadros.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Obx(() {
        final running = controller.running;
        final starting = controller.state.value == TestState.starting;
        final inference = controller.inferenceMs.value;
        final alert = controller.captureToAlertMs.value;
        final error = controller.error.value;
        final overGoal = inference >= AppConstants.inferenceLatencyGoalMs;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            CompanionHeader(
              eyebrow:
                  'Investigador · prueba ${controller.testCase.value.code}',
              title: 'Modo de pruebas',
              color: AppColors.cobalt,
              stepColor: AppColors.cobaltDeep,
              trailing: IconButton(
                tooltip: 'Salir del modo de pruebas',
                icon: const Icon(Icons.close, color: AppColors.paper),
                onPressed: () => Get.back<void>(),
              ),
              bottom: Semantics(
                liveRegion: true,
                child: Text(
                  running
                      ? 'Midiendo · ${mmss(controller.elapsed.value)} · '
                          '${controller.frames.value} cuadros'
                      : '${controller.logger.length} cuadros registrados',
                  style: text.titleMedium?.copyWith(color: AppColors.paper),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: text.bodyLarge?.copyWith(color: scheme.error),
                        ),
                      ),
                    ),
                  SectionCard(
                    title: 'Caso de prueba',
                    children: [
                      DropdownButtonFormField<TestCase>(
                        initialValue: controller.testCase.value,
                        isExpanded: true,
                        items: [
                          for (final c in TestCase.values)
                            DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.code} · ${c.title}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: running
                            ? null
                            : (c) {
                                if (c != null) {
                                  controller.testCase.value = c;
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      Text('Etiqueta real (lo que hay al frente)',
                          style: text.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in TestModeController.groundTruthOptions)
                            ChoiceChip(
                              label: Text(groundTruthName(g)),
                              selected: controller.groundTruth.value == g,
                              onSelected: (_) =>
                                  controller.groundTruth.value = g,
                            ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Incluir coordenadas GPS en el CSV'),
                        subtitle: const Text('Apagado por privacidad'),
                        value: controller.includeCoordinates.value,
                        onChanged: running
                            ? null
                            : (v) => controller.includeCoordinates.value = v,
                      ),
                    ],
                  ),
                  if (running) _Preview(controller: controller),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${ms(inference)} ms',
                          label: 'Inferencia (meta < 100)',
                          background:
                              overGoal ? AppColors.carmin : AppColors.esmeralda,
                          foreground: AppColors.paper,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: alert == null ? '—' : '${ms(alert)} ms',
                          label: 'Captura a alerta (meta ≤ 500)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: controller.fps.value
                              .toStringAsFixed(1)
                              .replaceAll('.', ','),
                          label: 'Cuadros por segundo',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: '${controller.logger.length}',
                          label: 'Muestras',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Inferencia por cuadro',
                    children: [
                      SizedBox(
                        height: 120,
                        child: Semantics(
                          label: 'Gráfica de inferencia de los últimos 30 '
                              'segundos con la meta de 100 milisegundos',
                          child: CustomPaint(
                            painter: InferenceChartPainter(
                              values: controller.chart.toList(),
                              goal: AppConstants.inferenceLatencyGoalMs
                                  .toDouble(),
                              line: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Línea: meta de 100 ms · Rojo: sobre la meta',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    style: running
                        ? FilledButton.styleFrom(
                            backgroundColor: AppColors.carmin,
                            foregroundColor: AppColors.paper,
                          )
                        : null,
                    icon: Icon(running ? Icons.stop : Icons.play_arrow),
                    label: Text(running ? 'Detener' : 'Iniciar medición'),
                    onPressed: starting
                        ? null
                        : (running ? controller.stop : controller.start),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Exportar CSV'),
                    onPressed: running ? null : () => _export(context),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: running ? null : controller.clearSamples,
                    child: const Text('Borrar mediciones'),
                  ),
                  Text(
                    'Las mediciones viven solo en memoria hasta exportarlas. '
                    'Al salir, la app vuelve a su comportamiento normal.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Vista de la cámara con las cajas, para comprobar qué mide la prueba.
class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final TestModeController controller;

  @override
  Widget build(BuildContext context) {
    final source = controller.videoSource;
    final camera = source is PhoneCameraSource ? source.controller : null;
    final overlay = DetectionOverlay(
      detections: controller.detections.toList(),
      announce: false,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 220,
          child: ColoredBox(
            color: AppColors.night,
            child: camera == null || !camera.value.isInitialized
                ? overlay
                : FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 300,
                      height: 300 * camera.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [CameraPreview(camera), overlay],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Gráfica de barras de la inferencia con la línea de la meta.
class InferenceChartPainter extends CustomPainter {
  InferenceChartPainter({
    required this.values,
    required this.goal,
    required this.line,
  });

  final List<double> values;
  final double goal;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final top = values.fold<double>(goal * 1.5, (a, b) => b > a ? b : a);
    double y(double v) => size.height - size.height * (v / top).clamp(0, 1);
    if (values.isNotEmpty) {
      final w = size.width / values.length;
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        canvas.drawRect(
          Rect.fromLTRB(
              i * w, y(v), (i + 1) * w - (w > 3 ? 1 : 0), size.height),
          Paint()..color = v >= goal ? AppColors.carmin : AppColors.esmeralda,
        );
      }
    }
    final gy = y(goal);
    final dash = Paint()
      ..color = line
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, gy), Offset(x + 5, gy), dash);
    }
  }

  @override
  bool shouldRepaint(InferenceChartPainter old) =>
      old.values.length != values.length ||
      (values.isNotEmpty && old.values.last != values.last) ||
      old.goal != goal ||
      old.line != line;
}
