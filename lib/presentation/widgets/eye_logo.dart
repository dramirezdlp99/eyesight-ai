import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Logotipo animado de EyeSight AI: un ojo sobre una baldosa cobalto que
/// parpadea y mira a los lados, con el iris en oro.
///
/// Conserva la idea del logotipo animado de la versión preliminar. Si el
/// teléfono tiene activado «Quitar animaciones», el ojo queda abierto y
/// quieto (accesibilidad). Con [closed] se muestra cerrado (escáner
/// detenido).
class EyeLogo extends StatefulWidget {
  const EyeLogo({
    super.key,
    this.size = 132,
    this.animate = true,
    this.closed = false,
  });

  final double size;
  final bool animate;
  final bool closed;

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
    _sync();
  }

  @override
  void didUpdateWidget(EyeLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        oldWidget.closed != widget.closed) {
      _sync();
    }
  }

  void _sync() {
    if (widget.animate && !widget.closed && !reduceMotionOf(context)) {
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
                openness: widget.closed ? 0 : EyePainter.opennessAt(t),
                pupilShift: widget.closed ? 0 : EyePainter.lookAt(t),
                tile: AppColors.cobalt,
                sclera: AppColors.paper,
                iris: AppColors.oro,
                pupil: AppColors.ink,
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
    required this.tile,
    required this.sclera,
    required this.iris,
    required this.pupil,
  });

  /// 1 = abierto, 0 = cerrado.
  final double openness;

  /// Desplazamiento horizontal de la mirada (−1 a 1).
  final double pupilShift;
  final Color tile;
  final Color sclera;
  final Color iris;
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

  /// Mirada: al frente, a la izquierda y luego a la derecha.
  static double lookAt(double t) {
    double ease(double a, double b, double x) {
      final p = ((x - a) / (b - a)).clamp(0.0, 1.0);
      return 0.5 - 0.5 * math.cos(p * math.pi);
    }

    if (t < 0.40) {
      return 0;
    }
    if (t < 0.70) {
      return -ease(0.40, 0.55, t);
    }
    if (t < 0.86) {
      return -1 + 1.8 * ease(0.70, 0.84, t);
    }
    return 0.8 * (1 - ease(0.86, 1.0, t));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final tileRect = Rect.fromCenter(center: c, width: s, height: s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tileRect, Radius.circular(s * 0.3)),
      Paint()..color = tile,
    );

    final w = s * 0.7;
    final open = openness.clamp(0.0, 1.0);
    final h = s * 0.32 * open;
    if (h < s * 0.03) {
      // Ojo cerrado: un párpado curvo con pestañas.
      final lid = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..strokeCap = StrokeCap.round
        ..color = sclera;
      final path = Path()
        ..moveTo(c.dx - w / 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy + s * 0.16, c.dx + w / 2, c.dy);
      canvas.drawPath(path, lid);
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
    final center = c.translate(pupilShift * s * 0.08, 0);
    canvas.drawCircle(center, s * 0.17, Paint()..color = iris);
    canvas.drawCircle(center, s * 0.075, Paint()..color = pupil);
    canvas.drawCircle(
      center.translate(-s * 0.045, -s * 0.045),
      s * 0.028,
      Paint()..color = sclera,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(EyePainter old) =>
      old.openness != openness ||
      old.pupilShift != pupilShift ||
      old.tile != tile ||
      old.sclera != sclera ||
      old.iris != iris ||
      old.pupil != pupil;
}
