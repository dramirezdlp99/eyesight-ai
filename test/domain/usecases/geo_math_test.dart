import 'package:eyesight_ai/domain/usecases/geo_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  test('distancia cero entre el mismo punto', () {
    expect(GeoMath.distanceMeters(pastoLat, pastoLng, pastoLat, pastoLng), 0);
  });

  test('una milésima de grado de latitud mide unos 111,3 m', () {
    expect(GeoMath.distanceMeters(0, 0, 0.001, 0), closeTo(111.319, 0.01));
  });

  test('distancia entre dos puntos de Pasto (valor de referencia)', () {
    expect(
      GeoMath.distanceMeters(1.2136, -77.2811, 1.2141, -77.2797),
      closeTo(165.455, 0.01),
    );
  });

  test('es simétrica', () {
    final a = GeoMath.distanceMeters(1.2136, -77.2811, 1.2141, -77.2797);
    final b = GeoMath.distanceMeters(1.2141, -77.2797, 1.2136, -77.2811);
    expect(a, closeTo(b, 1e-9));
  });
}
