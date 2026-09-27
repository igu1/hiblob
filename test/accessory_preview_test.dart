import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:hiblob/flutter.dart';

void main() {
  test('render accessory contact sheet', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFF3F0EB), ui.BlendMode.src);
    var i = 0;
    for (final band in shapeBands.entries) {
      canvas.save();
      canvas.translate((i % 4) * 180.0, (i ~/ 4) * 180.0);
      HiblobRenderer(
          name: 'cap-fit',
          options: HiblobOptions(
            traits: {'shape': (band.value.$1 + band.value.$2) / 2},
            accessories: const {
              'fringe': 1,
              'glasses': 1,
              'blush': 0,
              'antennae': 0
            },
          )).paint(canvas, const ui.Size(180, 180));
      canvas.restore();
      i++;
    }
    final image = await recorder.endRecording().toImage(720, 540);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('/tmp/opencode/accessories.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
