import 'dart:async';

import 'package:camera/camera.dart';

import '../../domain/entities/video_source_kind.dart';
import '../ai/camera_frame.dart';
import '../ai/letterbox.dart';
import 'i_video_source.dart';

/// Cámara trasera del teléfono, ubicada a la altura del pecho (numeral 1.8).
class PhoneCameraSource implements IVideoSource {
  PhoneCameraSource({
    this.resolution = ResolutionPreset.medium,
    Future<List<CameraDescription>> Function()? cameras,
  }) : _cameras = cameras ?? availableCameras;

  final ResolutionPreset resolution;
  final Future<List<CameraDescription>> Function() _cameras;

  CameraController? _controller;
  StreamController<CameraFrame>? _frames;

  /// Controlador activo, para mostrar la vista previa (perfil de baja visión
  /// y modo de pruebas).
  CameraController? get controller => _controller;

  @override
  VideoSourceKind get kind => VideoSourceKind.phone;

  @override
  Future<bool> isAvailable() async {
    try {
      return (await _cameras()).isNotEmpty;
    } on CameraException {
      return false;
    }
  }

  @override
  Future<Stream<CameraFrame>> start() async {
    await stop();
    final cameras = await _cameras();
    if (cameras.isEmpty) {
      throw CameraException('sin_camara', 'El teléfono no tiene cámara');
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    // Se cierra en stop(), que se llama al salir del escáner.
    // ignore: close_sinks
    final frames = StreamController<CameraFrame>();
    _controller = controller;
    _frames = frames;
    final rotation = back.sensorOrientation;
    await controller.startImageStream((image) {
      if (frames.isClosed || image.planes.length < 3) {
        return;
      }
      frames.add(
        CameraFrame(
          yuv: YuvFrame(
            width: image.width,
            height: image.height,
            y: image.planes[0].bytes,
            u: image.planes[1].bytes,
            v: image.planes[2].bytes,
            yRowStride: image.planes[0].bytesPerRow,
            uvRowStride: image.planes[1].bytesPerRow,
            uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
          ),
          rotationDegrees: rotation,
          capturedAt: DateTime.now(),
        ),
      );
    });
    return frames.stream;
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
    final frames = _frames;
    _frames = null;
    await frames?.close();
  }
}
