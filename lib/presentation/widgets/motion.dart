import 'dart:math' as math;

import 'package:flutter/material.dart';

/// `true` si el teléfono tiene activado «Quitar animaciones»: entonces las
/// animaciones decorativas quedan quietas (accesibilidad).
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Estado base de las animaciones en bucle de la interfaz.
abstract class _LoopState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController loop =
      AnimationController(vsync: this, duration: loopDuration);

  Duration get loopDuration;

  /// Posición de la animación cuando está detenida.
  double get restValue => 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      loop
        ..stop()
        ..value = restValue;
    } else if (!loop.isAnimating) {
      loop.repeat();
    }
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

/// Puntos que laten en secuencia: representan los pulsos de vibración
/// (3 = cerca, 2 = media distancia, 1 = lejos, HU04).
class PulseDots extends StatefulWidget {
  const PulseDots({
    super.key,
    required this.count,
    required this.color,
    this.size = 14,
  });

  final int count;
  final Color color;
  final double size;

  @override
  State<PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends _LoopState<PulseDots> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 1200);

  @override
  double get restValue => 0.6;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.count; i++)
            Padding(
              padding: EdgeInsets.only(right: widget.size * 0.6),
              child: Transform.scale(
                scale: _scaleFor(i),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _scaleFor(int i) {
    final t = (loop.value - i * 0.18) % 1;
    // Pulso corto al comienzo de cada ciclo.
    return t < 0.2 ? 1 + 0.35 * math.sin(t / 0.2 * math.pi) : 1;
  }
}

/// Línea de luz que recorre la imagen de la cámara: indica que el modelo
/// está analizando.
class ScanSweep extends StatefulWidget {
  const ScanSweep({super.key, this.color = Colors.white});

  final Color color;

  @override
  State<ScanSweep> createState() => _ScanSweepState();
}

class _ScanSweepState extends _LoopState<ScanSweep> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 2600);

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: loop,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(loop.value);
            final fade = t < 0.1 ? t / 0.1 : (t > 0.9 ? (1 - t) / 0.1 : 1.0);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: t * constraints.maxHeight,
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: widget.color,
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.7),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ondas que se expanden, como un radar: aviso de zona de riesgo (HU08).
class RadarRings extends StatefulWidget {
  const RadarRings({
    super.key,
    required this.color,
    required this.child,
    this.size = 200,
  });

  final Color color;
  final Widget child;
  final double size;

  @override
  State<RadarRings> createState() => _RadarRingsState();
}

class _RadarRingsState extends _LoopState<RadarRings> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 2400);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < 3; i++) _ring((loop.value + i / 3) % 1),
            Center(child: child),
          ],
        ),
        child: widget.child,
      ),
    );
  }

  Widget _ring(double t) => Transform.scale(
        scale: 0.35 + 0.9 * t,
        child: Opacity(
          opacity: (1 - t) * 0.9,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 4),
            ),
          ),
        ),
      );
}

/// Barras que suben y bajan mientras la app escucha (HU01, HU07).
class WaveBars extends StatefulWidget {
  const WaveBars({super.key, required this.color, this.height = 30});

  final Color color;
  final double height;

  @override
  State<WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends _LoopState<WaveBars> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 1100);

  @override
  double get restValue => 0.25;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 5,
                height: widget.height *
                    (0.35 +
                        0.65 *
                            (0.5 +
                                0.5 *
                                    math.sin((loop.value - i * 0.15) *
                                        2 *
                                        math.pi))),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cuenta regresiva circular de una pregunta por voz (HU07, CA3: 8 s).
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.duration,
    required this.color,
    this.size = 56,
  });

  final Duration duration;
  final Color color;
  final double size;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.duration.inSeconds;
    return Semantics(
      label: 'Tiempo para responder',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final left = (seconds * (1 - _controller.value)).ceil();
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1 - _controller.value,
                    strokeWidth: 5,
                    color: widget.color,
                    backgroundColor: widget.color.withValues(alpha: 0.18),
                  ),
                ),
                Text(
                  '$left',
                  style: TextStyle(
                    fontSize: widget.size * 0.34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Aparición escalonada: cada hijo sube y se desvanece hacia su lugar, una
/// sola vez al abrir la pantalla.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.children, this.gap = 10});

  final List<Widget> children;
  final double gap;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) SizedBox(height: widget.gap),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final start = i * 0.12;
              final t = Curves.easeOutCubic.transform(
                ((_controller.value - start) / (1 - start)).clamp(0.0, 1.0),
              );
              return Opacity(
                opacity: t,
                // TalkBack lee las tarjetas aunque aún estén apareciendo.
                alwaysIncludeSemantics: true,
                child: Transform.translate(
                  offset: Offset(0, 28 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: widget.children[i],
          ),
        ],
      ],
    );
  }
}
