/// Custom painter for animated hiblob frames.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/rendering.dart' show CustomPainter;

import 'animated_renderer.dart';

typedef AnimatedHiblobFrameBuilder = AnimatedHiblobFrame Function();

/// Paints elapsed-time frames from a cached [AnimatedHiblobRenderer].
class AnimatedHiblobPainter extends CustomPainter {
  /// The cached renderer whose paths are reused across frames.
  final AnimatedHiblobRenderer renderer;

  /// Produces the current pose, colors, and motion values for each repaint.
  final AnimatedHiblobFrameBuilder frameBuilder;

  /// Creates an animated painter driven by [repaint].
  AnimatedHiblobPainter({
    required this.renderer,
    required this.frameBuilder,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// Evaluates and returns the frame that would be painted now.
  AnimatedHiblobFrame get currentFrame => frameBuilder();

  @override
  void paint(ui.Canvas canvas, ui.Size size) =>
      renderer.paint(canvas, size, currentFrame);

  @override
  bool shouldRepaint(covariant AnimatedHiblobPainter oldDelegate) =>
      oldDelegate.renderer != renderer;
}
