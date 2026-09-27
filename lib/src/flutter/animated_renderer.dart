/// Canvas renderer for elapsed-time hiblob frames.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:hiblob/hiblob.dart' as core;

import '../shape.dart' show BlobPath;
import 'path.dart';

/// Everything the animated renderer needs for one paint.
class AnimatedHiblobFrame {
  /// Seeded idle and expression-loop values at the current elapsed time.
  final core.MotionFrame motion;

  /// The interpolated expression pose applied to this frame.
  final core.Pose pose;

  /// The interpolated body color.
  final ui.Color headColor;

  /// The interpolated eye color.
  final ui.Color eyeColor;

  /// The 0–1 hover lift and scale reaction.
  final double hover;

  /// The 0–1 ambient idle-motion amplitude.
  final double amplitude;

  /// Creates a complete renderer frame.
  const AnimatedHiblobFrame({
    required this.motion,
    required this.pose,
    required this.headColor,
    required this.eyeColor,
    this.hover = 0,
    this.amplitude = 0,
  });
}

/// A resolved figure whose paths stay fixed while transforms move.
class AnimatedHiblobRenderer {
  /// The name resolved into this renderer's cached geometry and motion seeds.
  final String name;

  /// The immutable non-expression options resolved with [name].
  final core.HiblobOptions options;

  late final core.HiblobLayout _layout;
  late final List<core.Petal> _petals;
  late final List<BlobPath> _extra;
  late final ui.Path _body;
  late final List<ui.Path> _eyes;
  late final ui.Path? _backdrop;
  late final ui.Color? _backdropColor;
  late final core.Palette _basePalette;

  /// The deterministic phases, periods, and directions for [name].
  late final core.MotionSeeds motionSeeds;

  /// Resolves geometry, paths, colors, and motion seeds once.
  AnimatedHiblobRenderer({
    required this.name,
    this.options = const core.HiblobOptions(),
  }) {
    final core.Resolved resolved = core.resolve(name, options);
    _layout = core.style.layout(resolved.t);
    _petals = _layout.petals;
    _extra = _layout.extra;
    _body = toUiPath(_layout.bodyPath());
    _eyes = [for (final BlobPath path in _layout.eyePaths()) toUiPath(path)];
    _basePalette = Map<String, String>.unmodifiable(resolved.palette);
    motionSeeds = core.motionSeeds(resolved.t);
    final core.BackdropGeometry? background = core.backdropFor(
      options.background,
      _basePalette,
      styleDefault: core.Backdrop.none,
    );
    _backdrop = background == null ? null : toUiPath(background.path);
    _backdropColor = background == null ? null : colorFromHex(background.fill);
  }

  /// Resolves the expression tint against this renderer's base palette.
  core.Palette paletteFor(core.Expression? expression) =>
      core.expressionPalette(_basePalette, expression ?? core.idle);

  bool get hasBackdrop => _backdrop != null;

  /// Paints one frame without regenerating body or eye paths.
  void paint(ui.Canvas canvas, ui.Size size, AnimatedHiblobFrame frame) {
    final double side = size.width < size.height ? size.width : size.height;
    if (side <= 0) return;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    _paintViewBox(canvas, frame);
    canvas.restore();
  }

  void _paintViewBox(ui.Canvas canvas, AnimatedHiblobFrame frame) {
    final ui.Path? backdrop = _backdrop;
    if (backdrop != null) {
      canvas.drawPath(backdrop, _fillPaint(_backdropColor!));
    }

    final core.MotionFrame motion = frame.motion;
    final core.Pose pose = frame.pose;
    final double hoverScale = 1 + 0.04 * frame.hover;

    canvas.save();
    canvas.translate(motion.shake.$1, motion.shake.$2);
    canvas.translate(50, 50);
    canvas.translate(0, -1.5 * frame.hover);
    canvas.scale(hoverScale);
    canvas.translate(-50, -50);

    canvas.translate(50, 50);
    canvas.scale(motion.breathe.$1, motion.breathe.$2);
    canvas.translate(-50, -50);

    canvas.translate(0, pose.bdy + motion.bob);
    final ui.Paint headPaint = _fillPaint(frame.headColor);
    for (final core.Petal petal in _petals) {
      canvas.drawPath(
        ui.Path()
          ..addOval(
            ui.Rect.fromCircle(
              center: ui.Offset(petal.cx, petal.cy),
              radius: petal.r,
            ),
          ),
        headPaint,
      );
    }
    for (final BlobPath extra in _extra) {
      canvas.drawPath(toUiPath(extra), headPaint);
    }
    canvas.drawPath(_body, headPaint);

    canvas.save();
    canvas.translate(motion.saccade.$1, motion.saccade.$2);
    for (var index = 0; index < _eyes.length; index++) {
      _paintEye(canvas, index, frame);
    }
    canvas.restore();
    canvas.restore();
  }

  void _paintEye(
    ui.Canvas canvas,
    int index,
    AnimatedHiblobFrame frame,
  ) {
    final core.Eye eye = _layout.eyes[index];
    final core.Pose pose = frame.pose;
    final core.MotionFrame motion = frame.motion;
    final double side = index == 0 ? -1 : 1;
    final double selected = index == 0 ? 0 : 1;
    final double phase = selected * (1 - pose.rock) +
        pose.rock * ((1 + side * motion.thinkingPhase) / 2);

    canvas.save();
    canvas.translate(
      eye.cx + pose.edx * side,
      eye.cy + pose.edy + phase * pose.edy2,
    );
    canvas.rotate(
      _radians(
        (pose.tilt + selected * pose.tilt2) * side + eye.rot * (1 - pose.lock),
      ),
    );
    canvas.scale(
      pose.esx + selected * pose.esx2,
      pose.esy + selected * pose.esy2,
    );
    canvas.rotate(_radians(-eye.rot));
    canvas.translate(-eye.cx, -eye.cy);

    canvas.translate(eye.cx, eye.cy);
    canvas.rotate(_radians(motion.wrap.rotation * side));
    canvas.scale(
      1 + motion.wrap.magnitudeX + motion.wrap.side * side,
      1 + motion.wrap.scaleY,
    );
    canvas.rotate(_radians(eye.rot));
    canvas.scale(1, motion.blink);
    canvas.rotate(_radians(-eye.rot));
    canvas.translate(-eye.cx, -eye.cy);

    canvas.drawPath(_eyes[index], _fillPaint(frame.eyeColor));
    canvas.restore();
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  ui.Paint _fillPaint(ui.Color color) => ui.Paint()
    ..color = color
    ..style = ui.PaintingStyle.fill;
}
