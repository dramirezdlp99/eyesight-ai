import 'package:eyesight_ai/core/ai/obstacle_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las clases de la delimitación (numeral 1.8) están en el catálogo', () {
    for (final label in [
      'person',
      'car',
      'motorcycle',
      'bicycle',
      'pole',
      'bollard',
      'traffic cone',
      'step',
      'pothole',
    ]) {
      expect(ObstacleCatalog.isObstacle(label), isTrue, reason: label);
    }
  });

  test('clases sin relación con la movilidad se descartan', () {
    expect(ObstacleCatalog.isObstacle('pizza'), isFalse);
    expect(ObstacleCatalog.isObstacle('tv'), isFalse);
  });

  test('normaliza guiones y mayúsculas', () {
    expect(ObstacleCatalog.normalize('Traffic_Cone'), 'traffic cone');
    expect(ObstacleCatalog.normalize('traffic-cone'), 'traffic cone');
    expect(ObstacleCatalog.spanishName('TRAFFIC_CONE'), 'Cono');
  });

  test('solo los fijos peligrosos crean zona (HU06)', () {
    expect(ObstacleCatalog.createsZone('pothole'), isTrue);
    expect(ObstacleCatalog.createsZone('construction'), isTrue);
    expect(ObstacleCatalog.createsZone('traffic cone'), isFalse);
    expect(ObstacleCatalog.createsZone('person'), isFalse);
    expect(ObstacleCatalog.createsZone('desconocido'), isFalse);
  });

  test('los tipos manuales tienen nombre en español (HU07)', () {
    expect(
      ObstacleCatalog.manualZoneTypes.map(ObstacleCatalog.spanishName),
      ['Hueco', 'Escalón', 'Obra', 'Riesgo'],
    );
  });

  test('una etiqueta desconocida se anuncia tal cual', () {
    expect(ObstacleCatalog.spanishName('kangaroo'), 'kangaroo');
  });
}
