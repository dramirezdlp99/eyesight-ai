import 'package:eyesight_ai/domain/usecases/zone_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  final step = zone(id: 'step1', type: 'step', radius: 20);

  test('avisa al entrar en el radio de una zona (HU08, CA1)', () {
    final m = ZoneMonitor();
    final w = m.check(pos(lat: pastoLat - metersToLat(18)), [step], t0);
    expect(w, isNotNull);
    expect(w!.zone.id, 'step1');
    expect(w.distanceM, closeTo(18, 0.01));
    expect(w.message, 'Atención: escalón a 18 metros');
  });

  test('no avisa fuera del radio', () {
    final m = ZoneMonitor();
    expect(m.check(pos(lat: pastoLat - metersToLat(25)), [step], t0), isNull);
  });

  test('no repite mientras sigue cerca, salvo pasados 60 s (HU08, CA2)', () {
    final m = ZoneMonitor();
    final p = pos(lat: pastoLat - metersToLat(10));
    expect(m.check(p, [step], t0), isNotNull);
    expect(m.check(p, [step], t0.add(const Duration(seconds: 30))), isNull);
    expect(m.check(p, [step], t0.add(const Duration(seconds: 60))), isNotNull);
  });

  test('se rearma al salir del radio más 10 m', () {
    final m = ZoneMonitor();
    expect(
        m.check(pos(lat: pastoLat - metersToLat(15)), [step], t0), isNotNull);
    // Sale a 25 m (radio + 5): aún no se rearma.
    m.check(pos(lat: pastoLat - metersToLat(25)), [step],
        t0.add(const Duration(seconds: 5)));
    expect(
      m.check(pos(lat: pastoLat - metersToLat(15)), [step],
          t0.add(const Duration(seconds: 10))),
      isNull,
    );
    // Sale a 35 m (radio + 15): se rearma y vuelve a avisar al entrar.
    m.check(pos(lat: pastoLat - metersToLat(35)), [step],
        t0.add(const Duration(seconds: 15)));
    expect(
      m.check(pos(lat: pastoLat - metersToLat(15)), [step],
          t0.add(const Duration(seconds: 20))),
      isNotNull,
    );
  });

  test('sin precisión suficiente (peor que 30 m) no avisa (HU08, CA4)', () {
    final m = ZoneMonitor();
    expect(m.check(pos(accuracy: 31), [step], t0), isNull);
    expect(m.check(pos(accuracy: 30), [step], t0), isNotNull);
  });

  test('anuncia primero la zona más cercana y luego la siguiente', () {
    final m = ZoneMonitor();
    final near = zone(id: 'a', type: 'pothole', lat: pastoLat + metersToLat(5));
    final far =
        zone(id: 'b', type: 'construction', lat: pastoLat + metersToLat(15));
    expect(m.check(pos(), [far, near], t0)!.zone.id, 'a');
    expect(
        m
            .check(pos(), [far, near], t0.add(const Duration(seconds: 3)))!
            .zone
            .id,
        'b');
  });

  test('usa el radio propio de cada zona', () {
    final m = ZoneMonitor();
    final small = zone(radius: 5, lat: pastoLat + metersToLat(8));
    expect(m.check(pos(), [small], t0), isNull);
  });

  test('mensaje en singular a 1 metro', () {
    final w = ZoneWarning(zone: zone(type: 'pothole'), distanceM: 1.2);
    expect(w.message, 'Atención: hueco a 1 metro');
  });
}
