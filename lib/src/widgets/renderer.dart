/// The Flutter renderer: resolves one hiblob and paints it with `dart:ui`.
///
/// Resolving once and painting many times is the fast path — [paint] applies
/// an optional [MotionFrame] (breathe, bob, blink, gaze) on top of the fixed
/// geometry, so a static and an animated hiblob share this exact code path.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:hiblob/hiblob.dart';

/// Converts a core [GeometryPath] into a `dart:ui` path.
ui.Path uiPathFrom(GeometryPath path) {
  final p = ui.Path();
  for (final c in path.commands) {
    switch (c) {
      case MoveTo(:final x, :final y):
        p.moveTo(x, y);
      case LineTo(:final x, :final y):
        p.lineTo(x, y);
      case CubicTo(
          :final c1x,
          :final c1y,
          :final c2x,
          :final c2y,
          :final x,
          :final y
        ):
        p.cubicTo(c1x, c1y, c2x, c2y, x, y);
      case QuadraticTo(:final cx, :final cy, :final x, :final y):
        p.quadraticBezierTo(cx, cy, x, y);
      case ClosePath():
        p.close();
    }
  }
  return p;
}

/// A resolved, ready-to-paint hiblob.
class HiblobRenderer {
  /// The resolved figure this renderer paints.
  final ResolvedHiblob resolved;

  /// Resolves [name] with [options] immediately.
  HiblobRenderer(
      {required String name, HiblobOptions options = const HiblobOptions()})
      : resolved = resolve(name, options: options);

  /// Wraps an already-resolved figure.
  HiblobRenderer.fromResolved(this.resolved);

  /// Paints the figure onto [canvas], mapping the 100-by-100 view box onto
  /// the largest square centered in [size].
  void paint(ui.Canvas canvas, ui.Size size,
      {MotionFrame frame = MotionFrame.zero}) {
    final side = math.min(size.width, size.height);
    if (side <= 0) return;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / viewBoxSize);
    _paintViewed(canvas, frame);
    canvas.restore();
  }

  void _paintViewed(ui.Canvas canvas, MotionFrame frame) {
    final backdrop = resolved.backdrop;
    if (backdrop != null) {
      canvas.drawPath(uiPathFrom(backdrop), _fillPaint(resolved.backdropColor));
    }

    // Body: bob is a plain translation; breathe scales vertically around the
    // body center so the figure "inhales" rather than sliding.
    canvas.save();
    canvas.translate(0, frame.bodyY);
    canvas.translate(50, 52);
    canvas.scale(1, frame.bodyScaleY);
    canvas.translate(-50, -52);
    final headPaint = _fillPaint(resolved.headColor);
    for (final part in resolved.body) {
      canvas.drawPath(uiPathFrom(part), headPaint);
    }
    canvas.restore();

    // Eyes: glances translate; blinks scale each open eye around its own
    // center. Closed-line eyes are already shut and never blink.
    for (final eye in resolved.eyes) {
      canvas.save();
      canvas.translate(frame.gazeX, frame.gazeY);
      if (!eye.strokeOnly && frame.blink > 0) {
        canvas.translate(eye.cx, eye.cy);
        canvas.scale(1, 1 - frame.blink.clamp(0.0, 1.0));
        canvas.translate(-eye.cx, -eye.cy);
      }
      for (final mark in eye.marks) {
        final path = uiPathFrom(mark);
        if (mark.stroke) {
          canvas.drawPath(
            path,
            ui.Paint()
              ..color = ui.Color(resolved.eyeColor)
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = mark.strokeWidth
              ..strokeCap = ui.StrokeCap.round
              ..strokeJoin = ui.StrokeJoin.round,
          );
        } else {
          canvas.drawPath(path, _fillPaint(resolved.eyeColor));
        }
      }
      canvas.restore();
    }
  }

  ui.Paint _fillPaint(int argb) => ui.Paint()..color = ui.Color(argb);
}
