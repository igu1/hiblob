/// CustomPainters for the hiblob widgets.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Listenable, ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:hiblob/hiblob.dart';

import 'renderer.dart';

export 'renderer.dart' show HiblobRenderer, uiPathFrom;

/// Paints a static hiblob — the painter behind the [Hiblob] widget.
class HiblobPainter extends CustomPainter {
  /// The figure to paint.
  final HiblobRenderer renderer;

  /// The motion frame to apply; [MotionFrame.zero] for a still figure.
  final MotionFrame frame;

  /// Creates a painter for [renderer] at [frame].
  const HiblobPainter(this.renderer, {this.frame = MotionFrame.zero});

  @override
  void paint(ui.Canvas canvas, ui.Size size) =>
      renderer.paint(canvas, size, frame: frame);

  @override
  bool shouldRepaint(HiblobPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.renderer != renderer;
}

/// Paints an animated hiblob: it computes its own [MotionFrame] from an
/// elapsed-time notifier each repaint, and crossfades between the previous
/// and current figure when the expression (or name) changes.
class AnimatedHiblobPainter extends CustomPainter {
  /// The figure currently shown.
  final HiblobRenderer renderer;

  /// The figure being faded out, if a crossfade is running.
  final HiblobRenderer? previous;

  /// The motion seeds of the current figure.
  final MotionSeeds seeds;

  /// Elapsed animation time in milliseconds.
  final ValueListenable<double> elapsedMs;

  /// Reads the current ambient-motion ramp in `[0, 1]`.
  final double Function() rampOf;

  /// Reads the current crossfade progress in `[0, 1]`.
  final double Function() fadeOf;

  /// Creates the painter; [repaint] must fire whenever any input changes.
  AnimatedHiblobPainter({
    required this.renderer,
    required this.previous,
    required this.seeds,
    required this.elapsedMs,
    required this.rampOf,
    required this.fadeOf,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final frame =
        motionAt(seeds, elapsedMs.value, ramp: rampOf().clamp(0.0, 1.0));
    final fade = fadeOf().clamp(0.0, 1.0);
    final prev = previous;
    final bounds = ui.Offset.zero & size;
    if (prev != null && fade < 1) {
      canvas.saveLayer(
        bounds,
        ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, 1 - fade),
      );
      prev.paint(canvas, size, frame: frame);
      canvas.restore();
    }
    if (fade < 1) {
      canvas.saveLayer(
        bounds,
        ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, fade),
      );
    }
    renderer.paint(canvas, size, frame: frame);
    if (fade < 1) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(AnimatedHiblobPainter oldDelegate) => true;
}
