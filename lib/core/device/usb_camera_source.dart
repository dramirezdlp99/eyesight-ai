import '../../domain/entities/video_source_kind.dart';
import '../ai/camera_frame.dart';
import 'i_video_source.dart';

/// Cámara USB UVC montada en gafas y conectada por OTG (RF19).
///
/// Según el estado del desarrollo (numeral 4.3.8), su integración corresponde
/// a una fase posterior. Mientras tanto se declara no disponible y el
/// selector conmuta a la cámara del teléfono y lo anuncia (RNF05).
class UsbCameraSource implements IVideoSource {
  const UsbCameraSource();

  @override
  VideoSourceKind get kind => VideoSourceKind.usb;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Stream<CameraFrame>> start() => Future.error(
      UnsupportedError('La cámara USB llega en una fase posterior'));

  @override
  Future<void> stop() async {}
}
