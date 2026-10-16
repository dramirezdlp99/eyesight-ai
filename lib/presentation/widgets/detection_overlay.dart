import 'package:flutter/material.dart';

import '../../core/ai/obstacle_catalog.dart';
import '../../core/config/app_constants.dart';
import '../../domain/entities/detection.dart';
import '../../domain/entities/proximity.dart';
import '../../domain/usecases/alert_policy.dart';
import '../theme/app_colors.dart';

/// Dibuja la franja de trayectoria y las cajas detectadas sobre la imagen
/// de la cámara (wireframe de la HU03).
///
/// Con [announce] expone un resumen accesible para TalkBack (RNF06); el
/// escáner lo desactiva porque ya anuncia las alertas por voz.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.detections,
    this.announce = true,
  });

  final List<Detection> detections;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      painter: DetectionPainter(detections),
      child: const SizedBox.expand(),
    );
    if (!announce) {
      return ExcludeSemantics(child: paint);
    }
    final summary = detections.isEmpty
        ? 'Sin obstáculos detectados'
        : detections.map(AlertPolicy.messageFor).join('. ');
    return Semantics(label: summary, liveRegion: true, child: paint);
  }
}

class DetectionPainter extends CustomPainter {
  DetectionPainter(this.detections);

  final List<Detection> detections;

  static Color colorFor(Proximity proximity) =>
      AppColors.forProximity(proximity);

  @override
  void paint(Canvas canvas, Size size) {
    // Franja de trayectoria: trapecio central inferior (numeral 2.5.8).
    final top = AppConstants.pathBandTop * size.height;
    final left = AppConstants.pathBandLeft * size.width;
    final right = AppConstants.pathBandRight * size.width;
    final narrow = (right - left) * 0.2;
    final band = Path()
      ..moveTo(left + narrow, top)
      ..lineTo(right - narrow, top)
      ..lineTo(right, size.height)
      ..lineTo(left, size.height)
      ..close();
    canvas.drawPath(
      band,
      Paint()..color = AppColors.cobalt.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.75),
    );

    for (final d in detections) {
      final color = colorFor(d.proximity);
      final rect = Rect.fromLTRB(
        d.box.left * size.width,
        d.box.top * size.height,
        d.box.right * size.width,
        d.box.bottom * size.height,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = d.inPath ? 4 : 2.5
          ..color = color,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${ObstacleCatalog.spanishName(d.label)} '
              '${d.confidence.toStringAsFixed(2).replaceAll('.', ',')}',
          style: TextStyle(
            color: AppColors.onProximity(d.proximity),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final chip = Rect.fromLTWH(
        rect.left,
        rect.top - label.height - 10 < 0
            ? rect.top
            : rect.top - label.height - 10,
        label.width + 20,
        label.height + 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, const Radius.circular(999)),
        Paint()..color = color,
      );
      label.paint(canvas, chip.topLeft.translate(10, 4));
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections;
}
