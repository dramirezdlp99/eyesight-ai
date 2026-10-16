import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Greca escalonada inspirada en los motivos geométricos de Nariño y en el
/// barniz de Pasto: firma visual de EyeSight AI.
class GrecaPainter extends CustomPainter {
  const GrecaPainter({this.offset = 0});

  /// Desplazamiento horizontal en píxeles (para animar la banda).
  final double offset;

  /// Ancho de cada módulo para una banda de 64 px de alto.
  static const double moduleWidth = 78;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / 64;
    final w = moduleWidth * k;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ink);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final start = -(offset % w) - w;
    for (var x = start; x < size.width; x += w) {
      _module(canvas, x, k);
    }
    canvas.restore();
  }

  void _module(Canvas canvas, double x, double k) {
    Path steps(List<double> pts) {
      final p = Path()..moveTo(x + pts[0] * k, pts[1] * k);
      for (var i = 2; i < pts.length; i += 2) {
        p.lineTo(x + pts[i] * k, pts[i + 1] * k);
      }
      return p..close();
    }

    canvas
      ..drawPath(
        steps([
          0,
          64,
          0,
          48,
          13,
          48,
          13,
          34,
          26,
          34,
          26,
          20,
          39,
          20,
          39,
          34,
          52,
          34,
          52,
          48,
          65,
          48,
          65,
          64
        ]),
        Paint()..color = AppColors.cobalt,
      )
      ..drawPath(
        steps([13, 64, 13, 52, 26, 52, 26, 40, 39, 40, 39, 52, 52, 52, 52, 64]),
        Paint()..color = AppColors.oro,
      )
      ..drawPath(
        steps([39, 0, 39, 12, 52, 12, 52, 24, 65, 24, 65, 12, 78, 12, 78, 0]),
        Paint()..color = AppColors.carmin,
      )
      ..drawPath(
        steps([0, 0, 0, 12, 13, 12, 13, 0]),
        Paint()..color = AppColors.esmeralda,
      );
  }

  @override
  bool shouldRepaint(GrecaPainter old) => old.offset != offset;
}

/// Banda de greca; con [animate] avanza lentamente.
class GrecaBand extends StatefulWidget {
  const GrecaBand({super.key, this.height = 64, this.animate = false});

  final double height;
  final bool animate;

  @override
  State<GrecaBand> createState() => _GrecaBandState();
}

class _GrecaBandState extends State<GrecaBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && !reduceMotionOf(context)) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final module = GrecaPainter.moduleWidth * widget.height / 64;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: GrecaPainter(offset: _controller.value * module * 2),
          ),
        ),
      ),
    );
  }
}

/// Escalones decorativos en la esquina de una tarjeta de color.
class GrecaCorner extends StatelessWidget {
  const GrecaCorner({
    super.key,
    required this.color,
    this.accent,
    this.width = 150,
    this.height = 110,
    this.bottom = false,
  });

  final Color color;
  final Color? accent;
  final double width;
  final double height;

  /// En la esquina inferior derecha en lugar de la superior.
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, height),
        painter: _CornerPainter(color, accent, bottom),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color, this.accent, this.bottom);

  final Color color;
  final Color? accent;
  final bool bottom;

  @override
  void paint(Canvas canvas, Size size) {
    const steps = 4;
    final sw = size.width / (steps + 1);
    final sh = size.height / steps;
    final path = Path();
    if (bottom) {
      path.moveTo(size.width, size.height);
      path.lineTo(0, size.height);
      for (var i = 0; i < steps; i++) {
        path
          ..lineTo(i * sw, size.height - (i + 1) * sh)
          ..lineTo((i + 1) * sw, size.height - (i + 1) * sh);
      }
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(size.width, 0);
      for (var i = 0; i < steps; i++) {
        path
          ..lineTo(size.width - (i + 1) * sw, i * sh)
          ..lineTo(size.width - (i + 1) * sw, (i + 1) * sh);
      }
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    final a = accent;
    if (a != null) {
      canvas.drawRect(
        Rect.fromLTWH(size.width - sw, 0, sw, sh),
        Paint()..color = a,
      );
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.color != color || old.accent != accent || old.bottom != bottom;
}
