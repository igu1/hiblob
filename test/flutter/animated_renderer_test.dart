import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:hiblob/hiblob.dart' as core;
import 'package:hiblob/flutter.dart';
import 'package:hiblob/src/flutter/path.dart' show colorFromHex;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selected elapsed frames rasterize deterministically and move',
      () async {
    final AnimatedHiblobRenderer renderer = AnimatedHiblobRenderer(
      name: 'alain',
      options: const core.HiblobOptions(
        background: core.Backdrop.squircle,
      ),
    );
    final ByteData first = await _raster(
      renderer,
      _frame(renderer, 0, 1),
    );
    final ByteData repeated = await _raster(
      renderer,
      _frame(renderer, 0, 1),
    );
    final ByteData later = await _raster(
      renderer,
      _frame(renderer, 1234, 1),
    );
    expect(_equal(first, repeated), isTrue);
    expect(_equal(first, later), isFalse);
  });

  test('the backdrop remains outside every motion transform', () async {
    final AnimatedHiblobRenderer renderer = AnimatedHiblobRenderer(
      name: 'alain',
      options: const core.HiblobOptions(
        background: core.Backdrop.square,
      ),
    );
    final ByteData first = await _raster(
      renderer,
      _frame(renderer, 0, 1),
    );
    final ByteData later = await _raster(
      renderer,
      _frame(renderer, 1234, 1),
    );
    expect(_pixel(first, 2, 2), _pixel(later, 2, 2));
    expect(_equal(first, later), isFalse, reason: 'the figure still moves');
  });

  test('secondary-eye wrap changes the composed eye raster', () async {
    final AnimatedHiblobRenderer renderer =
        AnimatedHiblobRenderer(name: 'alain');
    final AnimatedHiblobFrame reference = _frame(renderer, 1234, 1);
    expect(reference.motion.wrap.side, isNot(0));
    final core.MotionFrame withoutWrap = core.MotionFrame(
      shake: reference.motion.shake,
      breathe: reference.motion.breathe,
      bob: reference.motion.bob,
      saccade: reference.motion.saccade,
      thinkingPhase: reference.motion.thinkingPhase,
      blink: reference.motion.blink,
      wrap: const core.MotionWrap(
        magnitudeX: 0,
        side: 0,
        scaleY: 0,
        rotation: 0,
      ),
    );
    final AnimatedHiblobFrame flat = AnimatedHiblobFrame(
      motion: withoutWrap,
      pose: reference.pose,
      headColor: reference.headColor,
      eyeColor: reference.eyeColor,
      amplitude: reference.amplitude,
    );
    expect(
      _equal(await _raster(renderer, reference), await _raster(renderer, flat)),
      isFalse,
    );
  });

  test('thinking keeps its held seesaw loop', () async {
    final AnimatedHiblobRenderer renderer =
        AnimatedHiblobRenderer(name: 'thinking');
    final ByteData first = await _raster(
      renderer,
      _frame(renderer, 0, 0, expression: core.thinking),
    );
    final ByteData opposite = await _raster(
      renderer,
      _frame(renderer, 450, 0, expression: core.thinking),
    );
    expect(_equal(first, opposite), isFalse);
  });
}

AnimatedHiblobFrame _frame(
  AnimatedHiblobRenderer renderer,
  double time,
  double amplitude, {
  core.Expression expression = core.idle,
}) {
  final core.Palette palette = renderer.paletteFor(expression);
  return AnimatedHiblobFrame(
    motion: core.motionAt(
      renderer.motionSeeds,
      time,
      amplitude,
      shake: expression.pose.shake,
    ),
    pose: expression.pose,
    headColor: colorFromHex(palette[core.colorHead]!),
    eyeColor: colorFromHex(palette[core.colorEye]!),
    amplitude: amplitude,
  );
}

Future<ByteData> _raster(
  AnimatedHiblobRenderer renderer,
  AnimatedHiblobFrame frame,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  renderer.paint(canvas, const ui.Size(100, 100), frame);
  final ui.Image image = await recorder.endRecording().toImage(100, 100);
  return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

bool _equal(ByteData a, ByteData b) {
  if (a.lengthInBytes != b.lengthInBytes) return false;
  for (var index = 0; index < a.lengthInBytes; index++) {
    if (a.getUint8(index) != b.getUint8(index)) return false;
  }
  return true;
}

int _pixel(ByteData data, int x, int y) {
  final int offset = (y * 100 + x) * 4;
  return Object.hash(
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
    data.getUint8(offset + 3),
  );
}
