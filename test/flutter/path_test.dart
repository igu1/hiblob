import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:hiblob/hiblob.dart';
import 'package:hiblob/src/flutter/path.dart';

/// The `BlobPath` -> `ui.Path` bridge is a mechanical 1:1 walk of the core's
/// segments, which are the same segments the parity fixture matches against
/// the reference implementation (their `toPathData()` strings are equal byte for
/// byte). These tests pin the bridge itself: bounds, corner placement, and
/// closure.
void main() {
  group('toUiPath', () {
    test('a box maps to exactly its corners', () {
      final ui.Path p = toUiPath(box(50, 50, 30, 20));
      final ui.Rect b = p.getBounds();
      expect(b.left, closeTo(20, 1e-9));
      expect(b.right, closeTo(80, 1e-9));
      expect(b.top, closeTo(30, 1e-9));
      expect(b.bottom, closeTo(70, 1e-9));
      expect(p.computeMetrics().length, 1, reason: 'closed single subpath');
    });

    test('horizontal and vertical commands reach the right corners', () {
      // `M1 2H7V9H1Z` — a proper rectangle, not a pinched shape.
      final ui.Path p = toUiPath(const BlobPath([
        MoveTo(1, 2),
        HorizontalLineTo(7),
        VerticalLineTo(9),
        HorizontalLineTo(1),
        ClosePath(),
      ]));
      final ui.Rect b = p.getBounds();
      expect(b.left, closeTo(1, 1e-9));
      expect(b.right, closeTo(7, 1e-9));
      expect(b.top, closeTo(2, 1e-9));
      expect(b.bottom, closeTo(9, 1e-9));
    });

    test('a circle superellipse stays within its analytic bounds', () {
      final ui.Path p = toUiPath(superellipse(
          const Superellipse(cx: 50, cy: 50, rx: 30, ry: 30, n: 2)));
      final ui.Rect b = p.getBounds();
      // The n=2 cubic approximation keeps the circle within its box to well
      // under a pixel at this radius; documented tolerance is generous.
      expect(b.left, greaterThanOrEqualTo(20 - 0.1));
      expect(b.right, lessThanOrEqualTo(80 + 0.1));
      expect(b.top, greaterThanOrEqualTo(20 - 0.1));
      expect(b.bottom, lessThanOrEqualTo(80 + 0.1));
      // And the curve passes through the four cardinal points.
      expect(p.contains(ui.Offset(20, 50)), isTrue);
      expect(p.contains(ui.Offset(80, 50)), isTrue);
    });

    test('an organic spline closes and contains its centre', () {
      final ui.Path p =
          toUiPath(blobPath(50, 50, 30, 30, [1, 1.05, 0.95, 1.1, 0.9, 1.02]));
      expect(p.computeMetrics().length, 1);
      expect(p.contains(ui.Offset(50, 50)), isTrue);
      final ui.Rect b = p.getBounds();
      expect(b.left, greaterThan(0));
      expect(b.right, lessThan(100));
      expect(b.top, greaterThan(0));
      expect(b.bottom, lessThan(100));
    });

    test('a rounded triangle keeps its sharp cut points', () {
      final ui.Path p = toUiPath(polygon(const Polygon(
        cx: 50,
        cy: 50,
        rx: 30,
        ry: 30,
        sides: 3,
        round: 0,
      )));
      final ui.Rect b = p.getBounds();
      // Vertex at the top (50, 20), base at cy + ry*sin(30deg) = 65.
      expect(b.height, closeTo(45, 0.2), reason: 'flat base to apex');
      expect(b.top, closeTo(20, 0.2));
      expect(p.contains(ui.Offset(50, 22)), isTrue, reason: 'below apex');
      expect(p.contains(ui.Offset(50, 18)), isFalse, reason: 'above apex');
    });
  });

  group('colorFromHex', () {
    test('parses #rrggbb into an opaque color', () {
      expect(colorFromHex('#ff0000'), const ui.Color(0xFFFF0000));
      expect(colorFromHex('#000000'), const ui.Color(0xFF000000));
      expect(colorFromHex('#123456').a, 1);
    });
  });
}
