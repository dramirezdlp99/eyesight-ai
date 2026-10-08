import 'package:eyesight_ai/core/ai/frame_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 7, 9);

  test('un solo cuadro a la vez; los demás se descartan', () {
    final g = FrameGate();
    expect(g.tryAcquire(t0), isTrue);
    expect(g.tryAcquire(t0.add(const Duration(milliseconds: 300))), isFalse);
    expect(g.dropped, 1);
    g.release();
    expect(g.tryAcquire(t0.add(const Duration(milliseconds: 300))), isTrue);
  });

  test('no más de 10 cuadros por segundo (RNF03)', () {
    final g = FrameGate();
    expect(g.tryAcquire(t0), isTrue);
    g.release();
    expect(g.tryAcquire(t0.add(const Duration(milliseconds: 50))), isFalse);
    expect(g.tryAcquire(t0.add(const Duration(milliseconds: 100))), isTrue);
  });

  test('reset limpia el estado', () {
    final g = FrameGate()..tryAcquire(t0);
    g.reset();
    expect(g.busy, isFalse);
    expect(g.dropped, 0);
    expect(g.tryAcquire(t0), isTrue);
  });
}
