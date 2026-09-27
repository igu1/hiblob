/// Flutter `Path` conversion for the deterministic core's geometry.
///
/// The core speaks its own structured path ([BlobPath]) with a byte-exact SVG
/// serialization; this is the bridge to `dart:ui`. The conversion is a
/// 1:1 walk of the segments — the same geometry that the parity fixture
/// matches against the reference fixture reaches the canvas unchanged (the
/// reference vector's path strings equal `BlobPath.toPathData()` exactly).
library;

import 'dart:ui' as ui;

import '../shape.dart';

/// Converts the core's structured path into a `dart:ui` `Path`.
///
/// Coordinates are the *unrounded* doubles the core resolved, not the
/// two-decimal markup form — the canvas gets full precision and the markup
/// parity is a separate guarantee. Subpaths keep [ui.Path]'s nonzero winding,
/// which is exactly how the SVG fills the union of its parts.
ui.Path toUiPath(BlobPath path) {
  final ui.Path out = ui.Path();
  double x = 0;
  double y = 0;
  // `track` only updates the current point so horizontal/vertical commands
  // resolve correctly; issuing a moveTo here would split the contour.
  void track(double nx, double ny) {
    x = nx;
    y = ny;
  }

  for (final PathSegment seg in path.segments) {
    switch (seg) {
      case MoveTo(:final x, :final y):
        out.moveTo(x, y);
        track(x, y);
      case LineTo(:final x, :final y):
        out.lineTo(x, y);
        track(x, y);
      case CubicTo(
          :final c1x,
          :final c1y,
          :final c2x,
          :final c2y,
          :final x,
          :final y
        ):
        out.cubicTo(c1x, c1y, c2x, c2y, x, y);
        track(x, y);
      case QuadTo(:final cx, :final cy, :final x, :final y):
        out.quadraticBezierTo(cx, cy, x, y);
        track(x, y);
      case HorizontalLineTo(:final x):
        out.lineTo(x, y);
        track(x, y);
      case VerticalLineTo(:final y):
        out.lineTo(x, y);
        track(x, y);
      case ClosePath():
        out.close();
    }
  }
  return out;
}

/// Parses a `#rrggbb` hex (as the core's palette emits) into a fully opaque
/// `dart:ui` color.
ui.Color colorFromHex(String hex) {
  final int value = int.parse(hex.substring(1), radix: 16);
  return ui.Color(0xFF000000 | value);
}
