import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../core/config/app_constants.dart';

/// Gestos del escáner sobre toda el área (HU07 y HU09, RF14):
///
/// * doble toque: repetir la última alerta;
/// * deslizar el dedo a un lado: silenciar la voz 10 s;
/// * mantener presionado 2 s: marcar una zona de riesgo.
///
/// Con TalkBack activo los gestos los recibe el lector de pantalla, por eso
/// las mismas acciones se exponen como acciones semánticas (RNF06).
class ScannerGestures extends StatelessWidget {
  const ScannerGestures({
    super.key,
    required this.onDoubleTap,
    required this.onSwipe,
    required this.onLongPress,
    required this.onStop,
    required this.child,
  });

  final VoidCallback onDoubleTap;
  final VoidCallback onSwipe;
  final VoidCallback onLongPress;
  final VoidCallback onStop;
  final Widget child;

  /// Velocidad mínima (píxeles por segundo) para contar un deslizamiento.
  static const double minSwipeVelocity = 300;

  static const String semanticLabel =
      'Área del escáner. Doble toque: repetir. Mantener presionado: marcar '
      'zona. Desliza: silenciar.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      onTap: onDoubleTap,
      onLongPress: onLongPress,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Silenciar'): onSwipe,
        const CustomSemanticsAction(label: 'Terminar'): onStop,
      },
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          DoubleTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
            DoubleTapGestureRecognizer.new,
            (r) => r.onDoubleTap = onDoubleTap,
          ),
          HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
            (r) => r.onEnd = (details) {
              final velocity = details.primaryVelocity;
              if (velocity != null && velocity.abs() >= minSwipeVelocity) {
                onSwipe();
              }
            },
          ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: AppConstants.markZoneLongPress,
            ),
            (r) => r.onLongPress = onLongPress,
          ),
        },
        child: child,
      ),
    );
  }
}
