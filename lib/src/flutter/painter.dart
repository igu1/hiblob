/// The [CustomPainter] that backs the [Hiblob] widget.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show CustomPainter;

import 'package:hiblob/hiblob.dart' show HiblobOptions;

import 'renderer.dart';

/// Paints a static hiblob through [HiblobRenderer].
///
/// The painter owns the repaint decision ([shouldRepaint] compares the seed
/// and the options by value), not the sizing — the enclosing widget owns the
/// constraints. Sizing changes alone never repaint, since the renderer maps
/// the viewBox onto whatever canvas it is given.
class HiblobPainter extends CustomPainter {
  /// The name resolved by this painter.
  final String name;

  /// The immutable core options resolved by this painter.
  final HiblobOptions options;

  /// The wrapped renderer, kept so tests and the widget can share one
  /// resolution instead of resolving twice.
  final HiblobRenderer renderer;

  /// Creates a static painter and resolves its renderer immediately.
  HiblobPainter({required this.name, this.options = const HiblobOptions()})
      : renderer = HiblobRenderer(name: name, options: options);

  @override
  void paint(ui.Canvas canvas, ui.Size size) => renderer.paint(canvas, size);

  @override
  bool shouldRepaint(covariant HiblobPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.options != options;
}
