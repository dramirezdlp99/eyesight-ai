import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logotipo animado de EyeSight AI: un ojo que parpadea, mueve la pupila y
/// emite ondas que representan la percepción del entorno.
///
/// Conserva la idea del logotipo animado de la versión preliminar y la
/// mejora. Si el teléfono tiene activado «Quitar animaciones», el ojo se
/// muestra abierto y quieto (accesibilidad).
class EyeLogo extends StatefulWidget {
  const EyeLogo({super.key, this.size = 160, this.animate = true});

  final double size;
  final bool animate;

  @override
  State<EyeLogo> createState() => _EyeLogoState();
}

class _EyeLogoState extends State<EyeLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animate && !reduceMotion) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller
        ..stop()
        ..value = 0.25;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'EyeSight AI',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return CustomPaint(
              painter: EyePainter(
                openness: EyePainter.opennessAt(t),
                pupilShift: math.sin(t * 2 * math.pi),
                ripple: t,
                stroke: scheme.primary,
                sclera: scheme.surface,
                pupil: scheme.onSurface,
              ),
            );
          },
        ),
      ),
    );
  }
}

class EyePainter extends CustomPainter {
  const EyePainter({
    required this.openness,
    required this.pupilShift,
    required this.ripple,
    required this.stroke,
    required this.sclera,
    required this.pupil,
  });

  /// 1 = abierto, 0 = cerrado.
  final double openness;

  /// Desplazamiento horizontal de la pupila (−1 a 1).
  final double pupilShift;

  /// Fase de las ondas (0 a 1).
  final double ripple;
  final Color stroke;
  final Color sclera;
  final Color pupil;

  /// Parpadeo rápido cerca del final de cada ciclo.
  static double opennessAt(double t) {
    const start = 0.86;
    const end = 0.96;
    if (t < start || t > end) {
      return 1;
    }
    final p = (t - start) / (end - start); // 0 → 1
    final closed = p < 0.5 ? p * 2 : (1 - p) * 2; // 0 → 1 → 0
    return 1 - closed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);

    // Ondas de percepción.
    for (var k = 0; k < 2; k++) {
      final p = (ripple + k * 0.5) % 1;
      canvas.drawCircle(
        c,
        s * 0.33 + p * s * 0.16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018
          ..color = stroke.withValues(alpha: (1 - p) * 0.45),
      );
    }

    final w = s * 0.64;
    final open = openness < 0 ? 0.0 : (openness > 1 ? 1.0 : openness);
    final h = s * 0.30 * open;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round
      ..color = stroke;

    if (h < s * 0.02) {
      canvas.drawLine(c.translate(-w / 2, 0), c.translate(w / 2, 0), outline);
      return;
    }

    final eye = Path()
      ..moveTo(c.dx - w / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - h, c.dx + w / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + h, c.dx - w / 2, c.dy)
      ..close();
    canvas.drawPath(eye, Paint()..color = sclera);

    canvas.save();
    canvas.clipPath(eye);
    final iris = c.translate(pupilShift * s * 0.07, 0);
    canvas.drawCircle(iris, s * 0.125, Paint()..color = stroke);
    canvas.drawCircle(iris, s * 0.058, Paint()..color = pupil);
    canvas.drawCircle(
      iris.translate(-s * 0.03, -s * 0.03),
      s * 0.018,
      Paint()..color = sclera,
    );
    canvas.restore();

    canvas.drawPath(eye, outline);
  }

  @override
  bool shouldRepaint(EyePainter old) =>
      old.openness != openness ||
      old.pupilShift != pupilShift ||
      old.ripple != ripple ||
      old.stroke != stroke ||
      old.sclera != sclera ||
      old.pupil != pupil;
}
