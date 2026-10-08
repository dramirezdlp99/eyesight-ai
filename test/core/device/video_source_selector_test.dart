import 'package:eyesight_ai/core/ai/camera_frame.dart';
import 'package:eyesight_ai/core/device/i_video_source.dart';
import 'package:eyesight_ai/core/device/usb_camera_source.dart';
import 'package:eyesight_ai/core/device/video_source_selector.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements IVideoSource {
  FakeSource(this.kind, {this.available = true});

  @override
  final VideoSourceKind kind;
  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Stream<CameraFrame>> start() async => const Stream.empty();

  @override
  Future<void> stop() async {}
}

void main() {
  test('usa la cámara del teléfono cuando es la preferida', () async {
    final phone = FakeSource(VideoSourceKind.phone);
    final choice = await VideoSourceSelector({VideoSourceKind.phone: phone})
        .choose(VideoSourceKind.phone);
    expect(choice.source, phone);
    expect(choice.fellBack, isFalse);
  });

  test('usa la cámara USB si está disponible', () async {
    final usb = FakeSource(VideoSourceKind.usb);
    final choice = await VideoSourceSelector({
      VideoSourceKind.phone: FakeSource(VideoSourceKind.phone),
      VideoSourceKind.usb: usb,
    }).choose(VideoSourceKind.usb);
    expect(choice.source, usb);
    expect(choice.fellBack, isFalse);
  });

  test('sin cámara USB conmuta al teléfono y lo informa (HU02 CA5, RNF05)',
      () async {
    final phone = FakeSource(VideoSourceKind.phone);
    final choice = await VideoSourceSelector({
      VideoSourceKind.phone: phone,
      VideoSourceKind.usb: const UsbCameraSource(),
    }).choose(VideoSourceKind.usb);
    expect(choice.source, phone);
    expect(choice.fellBack, isTrue);
  });

  test('la cámara USB todavía no está disponible (fase posterior)', () async {
    const usb = UsbCameraSource();
    expect(await usb.isAvailable(), isFalse);
    await expectLater(usb.start(), throwsUnsupportedError);
  });
}
