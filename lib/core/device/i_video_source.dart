import '../../domain/entities/video_source_kind.dart';
import '../ai/camera_frame.dart';

/// Fuente de video intercambiable (patrón Strategy, RF19, RNF15).
abstract interface class IVideoSource {
  VideoSourceKind get kind;

  /// `true` si la fuente puede usarse en este momento.
  Future<bool> isAvailable();

  /// Inicia la captura y entrega los cuadros en un flujo.
  Future<Stream<CameraFrame>> start();

  Future<void> stop();
}
