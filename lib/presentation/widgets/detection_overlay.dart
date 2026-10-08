import 'package:flutter/material.dart';

import '../../core/ai/obstacle_catalog.dart';
import '../../core/config/app_constants.dart';
import '../../domain/entities/detection.dart';
import '../../domain/entities/proximity.dart';
import '../../domain/usecases/alert_policy.dart';

/// Dibuja la franja de trayectoria y las cajas detectadas sobre la imagen
/// de la cámara (wireframe de la HU03). Expone un resumen accesible para
/// TalkBack (RNF06).
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({super.key, required this.detections});

  final List<Detection> detections;

  @override
  Widget build(BuildContext context) {
    final summary = detections.isEmpty
        ? 'Sin obstáculos detectados'
        : detections.map(AlertPolicy.messageFor).join('. ');
    return Semantics(
      label: summary,
      liveRegion: true,
      child: CustomPaint(
        painter: DetectionPainter(detections),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  DetectionPainter(this.detections);

  final List<Detection> detections;

  static Color colorFor(Proximity proximity) => switch (proximity) {
        Proximity.near => const Color(0xFFE53935),
        Proximity.medium => const Color(0xFFFFB300),
        Proximity.far => const Color(0xFFB0BEC5),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final band = Rect.fromLTRB(
      AppConstants.pathBandLeft * size.width,
      AppConstants.pathBandTop * size.height,
      AppConstants.pathBandRight * size.width,
      size.height,
    );
    canvas.drawRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.6),
    );

    for (final d in detections) {
      final color = colorFor(d.proximity);
      final rect = Rect.fromLTRB(
        d.box.left * size.width,
        d.box.top * size.height,
        d.box.right * size.width,
        d.box.bottom * size.height,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = d.inPath ? 4 : 2
          ..color = color,
      );
      final label = TextPainter(
        text: TextSpan(
          text: ' ${ObstacleCatalog.spanishName(d.label)} · '
              '${d.proximity.spoken} ${d.confidence.toStringAsFixed(2)} ',
          style: TextStyle(
            color: Colors.black,
            backgroundColor: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final dy =
          rect.top - label.height < 0 ? rect.top : rect.top - label.height;
      label.paint(canvas, Offset(rect.left, dy));
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections;
}
