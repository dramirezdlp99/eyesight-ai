import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/ai/camera_frame.dart';
import '../../../core/ai/frame_gate.dart';
import '../../../core/ai/i_obstacle_detector.dart';
import '../../../core/ai/yolo_litert_detector.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/device/phone_camera_source.dart';
import '../../../domain/entities/detection.dart';
import '../../widgets/detection_overlay.dart';

/// Vista de verificación del Bloque 2: cámara, modelo y tiempos en vivo.
///
/// En el Bloque 4 se integra al modo de pruebas del investigador (HU15).
class DetectionDebugView extends StatefulWidget {
  const DetectionDebugView({super.key});

  @override
  State<DetectionDebugView> createState() => _DetectionDebugViewState();
}

class _DetectionDebugViewState extends State<DetectionDebugView> {
  final IObstacleDetector _detector = YoloLiteRtDetector();
  final PhoneCameraSource _source = PhoneCameraSource();
  final FrameGate _gate = FrameGate();
  StreamSubscription<CameraFrame>? _subscription;

  String _status = 'Cargando el modelo…';
  List<Detection> _detections = const [];
  double _fps = 0;
  int _inferenceMs = 0;
  int _captureToResultMs = 0;
  int _windowCount = 0;
  DateTime? _windowStart;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _detector.load();
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Abriendo la cámara…');
      final frames = await _source.start();
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Detectando');
      _subscription = frames.listen(_onFrame);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    }
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (!_gate.tryAcquire(frame.capturedAt)) {
      return;
    }
    try {
      final result = await _detector.detect(
        frame,
        confidenceThreshold: AppConstants.defaultConfidenceThreshold,
      );
      if (!mounted) {
        return;
      }
      final now = DateTime.now();
      _windowCount++;
      final start = _windowStart ??= now;
      final elapsed = now.difference(start).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = _windowCount * 1000 / elapsed;
        _windowCount = 0;
        _windowStart = now;
      }
      setState(() {
        _detections = result.detections;
        _inferenceMs = result.inferenceMicros ~/ 1000;
        _captureToResultMs = now.difference(frame.capturedAt).inMilliseconds;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    } finally {
      _gate.release();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_source.stop());
    unawaited(_detector.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _source.controller;
    final Widget preview;
    if (controller != null && controller.value.isInitialized) {
      preview = AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            DetectionOverlay(detections: _detections),
          ],
        ),
      );
    } else {
      preview = Text(_status, textAlign: TextAlign.center);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de detección')),
      body: Column(
        children: [
          Expanded(child: Center(child: preview)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado: $_status'),
                Text(
                    'Cuadros por segundo: ${_fps.toStringAsFixed(1)} (meta 5 a 10)'),
                Text('Inferencia: $_inferenceMs ms (meta < 100 ms)'),
                Text(
                    'Captura a resultado: $_captureToResultMs ms (meta ≤ 500 ms)'),
                Text('Cuadros descartados: ${_gate.dropped}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
