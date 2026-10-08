import '../../domain/entities/video_source_kind.dart';
import 'i_video_source.dart';

/// Fuente elegida y si hubo que conmutar a la cámara del teléfono.
class VideoSourceChoice {
  const VideoSourceChoice({required this.source, required this.fellBack});

  final IVideoSource source;

  /// `true` si se pidió la cámara USB y no estaba disponible (HU02 CA5,
  /// HU13 CA3): la interfaz debe anunciarlo por voz.
  final bool fellBack;
}

/// Elige la fuente de video según los ajustes, con respaldo en la cámara del
/// teléfono (RF19, RNF05).
class VideoSourceSelector {
  const VideoSourceSelector(this.sources);

  final Map<VideoSourceKind, IVideoSource> sources;

  Future<VideoSourceChoice> choose(VideoSourceKind preferred) async {
    final wanted = sources[preferred];
    if (wanted != null && await wanted.isAvailable()) {
      return VideoSourceChoice(source: wanted, fellBack: false);
    }
    final phone = sources[VideoSourceKind.phone];
    if (phone == null) {
      throw StateError('No hay cámara del teléfono configurada');
    }
    return VideoSourceChoice(
      source: phone,
      fellBack: preferred != VideoSourceKind.phone,
    );
  }
}
