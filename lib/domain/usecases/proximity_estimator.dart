import 'dart:ui' show Rect;

import '../../core/config/app_constants.dart';
import '../entities/detection.dart';
import '../entities/proximity.dart';

/// Estima la cercanía relativa y si el obstáculo está en la trayectoria
/// (numeral 2.5.8, RF05).
///
/// Con la cámara a la altura del pecho, un obstáculo cercano toca el suelo
/// cerca del borde inferior de la imagen y ocupa una mayor altura. Por eso se
/// evalúan el borde inferior de la caja y su altura relativa.
class ProximityEstimator {
  const ProximityEstimator({
    this.bandLeft = AppConstants.pathBandLeft,
    this.bandRight = AppConstants.pathBandRight,
    this.bandTop = AppConstants.pathBandTop,
  });

  final double bandLeft;
  final double bandRight;
  final double bandTop;

  Proximity estimate(Rect box) {
    if (box.bottom >= AppConstants.nearBottom ||
        box.height >= AppConstants.nearHeight) {
      return Proximity.near;
    }
    if (box.bottom >= AppConstants.mediumBottom ||
        box.height >= AppConstants.mediumHeight) {
      return Proximity.medium;
    }
    return Proximity.far;
  }

  /// `true` si la caja entra en la franja central e inferior: su borde
  /// inferior baja de [bandTop] y al menos un tercio de su ancho, o su
  /// centro, queda dentro de la franja horizontal.
  bool isInPath(Rect box) {
    if (box.bottom < bandTop) {
      return false;
    }
    final center = box.center.dx;
    if (center >= bandLeft && center <= bandRight) {
      return true;
    }
    final overlap = (box.right < bandRight ? box.right : bandRight) -
        (box.left > bandLeft ? box.left : bandLeft);
    return box.width > 0 && overlap > 0 && overlap / box.width >= 1 / 3;
  }

  /// Devuelve la detección con su cercanía y su posición en la trayectoria.
  Detection annotate(Detection detection) => detection.copyWith(
        proximity: estimate(detection.box),
        inPath: isInPath(detection.box),
      );
}
