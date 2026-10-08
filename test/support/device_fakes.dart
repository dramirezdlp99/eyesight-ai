import 'dart:collection';

import 'package:eyesight_ai/core/device/haptics.dart';
import 'package:eyesight_ai/core/device/location_service.dart';
import 'package:eyesight_ai/core/device/permission_guard.dart';
import 'package:eyesight_ai/core/device/speech_service.dart';
import 'package:eyesight_ai/core/device/voice_input.dart';
import 'package:eyesight_ai/domain/entities/geo_position.dart';

/// Voz falsa: guarda lo que la app dice, en orden.
class FakeSpeech implements ISpeechService {
  final List<String> spoken = [];
  double? rate;
  double? volume;
  int stops = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> configure({required double rate, required double volume}) async {
    this.rate = rate;
    this.volume = volume;
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async =>
      spoken.add(text);

  @override
  Future<void> stop() async => stops++;
}

/// Reconocimiento de voz falso: devuelve las respuestas programadas, una por
/// cada escucha, y `null` cuando se acaban.
class FakeVoice implements IVoiceInput {
  FakeVoice([List<String?> answers = const []]) : _answers = Queue.of(answers);

  final Queue<String?> _answers;
  bool available = true;
  int listens = 0;
  int stops = 0;

  @override
  Future<bool> init() async => available;

  @override
  Future<String?> listenOnce(
      {Duration timeout = const Duration(seconds: 8)}) async {
    listens++;
    return _answers.isEmpty ? null : _answers.removeFirst();
  }

  @override
  Future<void> stop() async => stops++;
}

class FakeHaptics implements IHaptics {
  final List<List<int>> played = [];

  @override
  Future<void> play(List<int> pattern) async => played.add(pattern);
}

class FakeLocation implements ILocationService {
  FakeLocation([this.position]);

  GeoPosition? position;
  bool ready = true;

  @override
  Future<bool> ensureReady() async => ready;

  @override
  Future<GeoPosition?> current() async => position;
}

class FakePermissions implements IPermissionGuard {
  final Set<AppPermission> granted = {};
  bool grantOnRequest = true;
  final List<AppPermission> requested = [];

  @override
  Future<bool> isGranted(AppPermission permission) async =>
      granted.contains(permission);

  @override
  Future<bool> request(AppPermission permission) async {
    requested.add(permission);
    if (grantOnRequest) {
      granted.add(permission);
    }
    return grantOnRequest;
  }
}
