import 'dart:ui';

import 'package:eyesight_ai/domain/entities/detection.dart';
import 'package:eyesight_ai/domain/entities/geo_position.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/risk_zone.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';

/// Coordenadas de referencia en el centro de Pasto.
const double pastoLat = 1.2136;
const double pastoLng = -77.2811;

/// Grados de latitud equivalentes a [meters] metros.
double metersToLat(double meters) => meters / 111319.49079327357;

final DateTime t0 = DateTime(2026, 10, 7, 9);

Detection det(
  String label, {
  double confidence = 0.8,
  Rect box = const Rect.fromLTRB(0.4, 0.5, 0.6, 0.9),
  Proximity proximity = Proximity.near,
  bool inPath = true,
}) =>
    Detection(
      label: label,
      confidence: confidence,
      box: box,
      proximity: proximity,
      inPath: inPath,
    );

GeoPosition pos({
  double lat = pastoLat,
  double lng = pastoLng,
  double accuracy = 5,
  DateTime? at,
}) =>
    GeoPosition(
      latitude: lat,
      longitude: lng,
      accuracyM: accuracy,
      timestamp: at ?? t0,
    );

RiskZone zone({
  String id = 'z1',
  String type = 'pothole',
  double lat = pastoLat,
  double lng = pastoLng,
  double radius = 20,
  ZoneOrigin origin = ZoneOrigin.automatic,
  int count = 1,
  DateTime? created,
  DateTime? lastSeen,
}) =>
    RiskZone(
      id: id,
      type: type,
      lat: lat,
      lng: lng,
      radiusM: radius,
      origin: origin,
      count: count,
      createdAt: created ?? t0,
      lastSeenAt: lastSeen ?? created ?? t0,
    );

/// Generador de identificadores predecible para las pruebas.
String Function() sequentialIds([String prefix = 'id']) {
  var n = 0;
  return () => '$prefix${++n}';
}
