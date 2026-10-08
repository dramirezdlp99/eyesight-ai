import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/entities/detection.dart';
import '../../domain/usecases/proximity_estimator.dart';
import 'camera_frame.dart';
import 'frame_processor.dart';
import 'i_obstacle_detector.dart';
import 'letterbox.dart';
import 'model_manifest.dart';
import 'tensor_codec.dart';

/// Detector YOLOv8n ejecutado con LiteRT en un hilo aislado (numeral 3.12.5).
///
/// El hilo aislado conserva el intérprete y hace todo el trabajo pesado del
/// cuadro (conversión YUV, inferencia y NMS); la interfaz solo recibe la
/// lista de cajas. Así la interfaz nunca se congela (STRIDE: denegación de
/// servicio) y se corrige la conversión lenta de la versión preliminar.
class YoloLiteRtDetector implements IObstacleDetector {
  YoloLiteRtDetector({
    this.threads = 4,
    this.estimator = const ProximityEstimator(),
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final int threads;
  final ProximityEstimator estimator;
  final AssetBundle _bundle;

  ReceivePort? _fromWorker;
  SendPort? _toWorker;
  final Map<int, Completer<_WorkerResult>> _pending = {};
  int _nextId = 0;

  ModelManifest? manifest;
  ModelIO? modelIO;

  @override
  bool get isReady => _toWorker != null;

  @override
  Future<void> load() async {
    if (isReady) {
      return;
    }
    final parsed = ModelManifest.parse(
      await _bundle.loadString(ModelManifest.assetPath),
    );
    final data = await _bundle.load(parsed.modelAsset);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // Verificación de integridad antes de ejecutar el modelo (numeral 4.1.7).
    ModelIntegrity.verify(bytes, parsed);
    final labels = ModelIntegrity.parseLabels(
      await _bundle.loadString(parsed.labelsAsset),
    );

    final port = ReceivePort();
    final ready = Completer<Object?>();
    port.listen((message) {
      if (!ready.isCompleted) {
        ready.complete(message);
        return;
      }
      if (message is _WorkerResult) {
        _pending.remove(message.id)?.complete(message);
      } else {
        _failAll('El hilo del modelo se detuvo: $message');
      }
    });
    _fromWorker = port;
    await Isolate.spawn(
      _workerMain,
      _WorkerInit(
        reply: port.sendPort,
        model: TransferableTypedData.fromList([bytes]),
        labels: labels,
        threads: threads,
      ),
      onError: port.sendPort,
      debugName: 'eyesight-yolo',
    );
    final first = await ready.future;
    if (first is! _WorkerReady) {
      await dispose();
      throw StateError('No se pudo iniciar el modelo: $first');
    }
    _toWorker = first.port;
    manifest = parsed;
    modelIO = first.io;
  }

  @override
  Future<FrameDetections> detect(
    CameraFrame frame, {
    required double confidenceThreshold,
  }) async {
    final port = _toWorker;
    if (port == null) {
      throw StateError('El modelo no está cargado');
    }
    final id = _nextId++;
    final completer = Completer<_WorkerResult>();
    _pending[id] = completer;
    final f = frame.yuv;
    port.send(
      _WorkerRequest(
        id: id,
        y: TransferableTypedData.fromList([f.y]),
        u: TransferableTypedData.fromList([f.u]),
        v: TransferableTypedData.fromList([f.v]),
        width: f.width,
        height: f.height,
        yRowStride: f.yRowStride,
        uvRowStride: f.uvRowStride,
        uvPixelStride: f.uvPixelStride,
        rotationDegrees: frame.rotationDegrees,
        confidenceThreshold: confidenceThreshold,
      ),
    );
    final result = await completer.future;
    final error = result.error;
    if (error != null) {
      throw StateError(error);
    }
    return FrameDetections(
      detections: [
        for (final b in result.boxes)
          estimator.annotate(
            Detection(label: b.label, confidence: b.score, box: b.box),
          ),
      ],
      capturedAt: frame.capturedAt,
      inferenceMicros: result.inferenceMicros,
      totalMicros: result.totalMicros,
    );
  }

  @override
  Future<void> dispose() async {
    _toWorker?.send(const _WorkerClose());
    _toWorker = null;
    _failAll('El detector se cerró');
    _fromWorker?.close();
    _fromWorker = null;
  }

  void _failAll(String reason) {
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete(_WorkerResult.failure(-1, reason));
      }
    }
    _pending.clear();
  }
}

// ---------------------------------------------------------------- Hilo aislado

class _WorkerInit {
  const _WorkerInit({
    required this.reply,
    required this.model,
    required this.labels,
    required this.threads,
  });

  final SendPort reply;
  final TransferableTypedData model;
  final List<String> labels;
  final int threads;
}

class _WorkerReady {
  const _WorkerReady(this.port, this.io);

  final SendPort port;
  final ModelIO io;
}

class _WorkerRequest {
  const _WorkerRequest({
    required this.id,
    required this.y,
    required this.u,
    required this.v,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotationDegrees,
    required this.confidenceThreshold,
  });

  final int id;
  final TransferableTypedData y;
  final TransferableTypedData u;
  final TransferableTypedData v;
  final int width;
  final int height;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final int rotationDegrees;
  final double confidenceThreshold;
}

class _WorkerClose {
  const _WorkerClose();
}

class _WorkerResult {
  const _WorkerResult({
    required this.id,
    required this.boxes,
    required this.inferenceMicros,
    required this.totalMicros,
  }) : error = null;

  const _WorkerResult.failure(this.id, String this.error)
      : boxes = const [],
        inferenceMicros = 0,
        totalMicros = 0;

  final int id;
  final List<FrameBox> boxes;
  final int inferenceMicros;
  final int totalMicros;
  final String? error;
}

TensorKind _kindOf(TensorType type) => switch (type) {
      TensorType.int8 => TensorKind.int8,
      TensorType.uint8 => TensorKind.uint8,
      TensorType.float32 => TensorKind.float32,
      _ => throw UnsupportedError('Tipo de tensor no soportado: $type'),
    };

/// Crea el intérprete y el procesador dentro del hilo aislado. Si falla,
/// informa el error al hilo principal y devuelve `null`.
(Interpreter, FrameProcessor)? _setup(_WorkerInit init, SendPort inbox) {
  try {
    final options = InterpreterOptions()..threads = init.threads;
    final interpreter = Interpreter.fromBuffer(
      init.model.materialize().asUint8List(),
      options: options,
    );
    interpreter.allocateTensors();
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    final io = ModelIO(
      inputSize: input.shape[1],
      inputKind: _kindOf(input.type),
      inputScale: input.params.scale,
      inputZeroPoint: input.params.zeroPoint,
      outputShape: output.shape,
      outputKind: _kindOf(output.type),
      outputScale: output.params.scale,
      outputZeroPoint: output.params.zeroPoint,
    );
    final processor = FrameProcessor(
      io: io,
      labels: init.labels,
      run: (bytes) {
        input.data = bytes;
        interpreter.invoke();
        return Uint8List.fromList(output.data);
      },
    );
    init.reply.send(_WorkerReady(inbox, io));
    return (interpreter, processor);
  } catch (e) {
    init.reply.send('Error al cargar el modelo: $e');
    return null;
  }
}

void _workerMain(_WorkerInit init) {
  final inbox = ReceivePort();
  final setup = _setup(init, inbox.sendPort);
  if (setup == null) {
    inbox.close();
    return;
  }
  final (interpreter, processor) = setup;
  inbox.listen((message) {
    if (message is _WorkerRequest) {
      try {
        final result = processor.process(
          YuvFrame(
            width: message.width,
            height: message.height,
            y: message.y.materialize().asUint8List(),
            u: message.u.materialize().asUint8List(),
            v: message.v.materialize().asUint8List(),
            yRowStride: message.yRowStride,
            uvRowStride: message.uvRowStride,
            uvPixelStride: message.uvPixelStride,
          ),
          rotationDegrees: message.rotationDegrees,
          confidenceThreshold: message.confidenceThreshold,
        );
        init.reply.send(
          _WorkerResult(
            id: message.id,
            boxes: result.boxes,
            inferenceMicros: result.inferenceMicros,
            totalMicros: result.totalMicros,
          ),
        );
      } catch (e) {
        init.reply.send(_WorkerResult.failure(message.id, '$e'));
      }
    } else if (message is _WorkerClose) {
      interpreter.close();
      inbox.close();
    }
  });
}
