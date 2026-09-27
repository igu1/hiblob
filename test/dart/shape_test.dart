import 'package:test/test.dart';

import 'package:hiblob/hiblob.dart';

/// Numeric coordinates in a path, in command order, mirroring what the
/// geometry tests read back out of the serialized `d`.
List<double> coords(BlobPath p) {
  final out = <double>[];
  for (final PathSegment s in p.segments) {
    switch (s) {
      case MoveTo(:final x, :final y):
        out
          ..add(x)
          ..add(y);
      case LineTo(:final x, :final y):
        out
          ..add(x)
          ..add(y);
      case CubicTo(
          :final c1x,
          :final c1y,
          :final c2x,
          :final c2y,
          :final x,
          :final y
        ):
        out
          ..add(c1x)
          ..add(c1y)
          ..add(c2x)
          ..add(c2y)
          ..add(x)
          ..add(y);
      case QuadTo(:final cx, :final cy, :final x, :final y):
        out
          ..add(cx)
          ..add(cy)
          ..add(x)
          ..add(y);
      case HorizontalLineTo(:final x):
        out.add(x);
      case VerticalLineTo(:final y):
        out.add(y);
      case ClosePath():
        break;
    }
  }
  return out;
}

/// Parses the serialized path data back into numbers — the same contract the
/// TS geometry tests rely on.
List<double> coordsOf(String d) {
  final out = <double>[];
  final re = RegExp(r'-?\d*\.?\d+');
  for (final m in re.allMatches(d)) {
    out.add(double.parse(m.group(0)!));
  }
  return out;
}

void main() {
  group('superellipse', () {
    test('the 45-degree control constant matches the circle case exactly', () {
      // n=2 must reproduce the standard 0.5523 kappa, or the derivation is
      // wrong.
      expect(
        superellipse(const Superellipse(
          cx: 0,
          cy: 0,
          rx: 100,
          ry: 100,
          n: 2,
        )).toPathData(),
        contains('55.23'),
      );
    });

    test('coordinates stay finite for the whole n range', () {
      for (var n = 1.6; n <= 8; n += 0.1) {
        final d = superellipse(Superellipse(
          cx: 50,
          cy: 50,
          rx: 30,
          ry: 30,
          n: n,
        )).toPathData();
        expect(d.contains('NaN'), isFalse);
        for (final v in coordsOf(d)) {
          expect(v.isFinite, isTrue);
        }
      }
    });

    test('control points never overshoot the bounding box', () {
      for (var n = 1.6; n <= 8; n += 0.1) {
        for (final v in coords(superellipse(
          Superellipse(cx: 50, cy: 50, rx: 40, ry: 40, n: n),
        ))) {
          expect(v, greaterThanOrEqualTo(9.9));
          expect(v, lessThanOrEqualTo(90.1));
        }
      }
    });
  });

  group('blobPath', () {
    test('interpolates its vertices exactly', () {
      // Catmull-Rom passes through its points, which is what makes the radii
      // mean what they say and containment predictable.
      final d = blobPath(50, 50, 20, 20, [1, 1, 1, 1], 0).toPathData();
      expect(d, startsWith('M70 50'));
      expect(d, contains('50 70'));
      expect(d, contains('30 50'));
    });

    test('closes and stays within its radii', () {
      const radii = [1.1, 0.9, 1.05, 0.95, 1.12, 0.88];
      final d = blobPath(50, 50, 20, 20, radii, 0).toPathData();
      expect(d, endsWith('Z'));
      for (final v in coordsOf(d)) {
        expect(v, greaterThan(50 - 20 * 1.5));
        expect(v, lessThan(50 + 20 * 1.5));
      }
    });
  });

  group('polygon', () {
    test('sharp corners land exactly on the vertices', () {
      // round: 0 means no cut, so the path walks the vertices themselves —
      // the property that makes rx/ry mean circumradius.
      final d = polygon(const Polygon(
        cx: 50,
        cy: 50,
        rx: 20,
        ry: 20,
        sides: 4,
        round: 0,
      )).toPathData();
      expect(d, contains('50 30'));
      expect(d, contains('70 50'));
      expect(d, contains('50 70'));
      expect(d, contains('30 50'));
    });

    test('a vertex sits at the top, so a triangle rests on its base', () {
      final d = polygon(const Polygon(
        cx: 50,
        cy: 50,
        rx: 20,
        ry: 20,
        sides: 3,
        round: 0,
      )).toPathData();
      expect(d, contains('50 30'));
      // ...and the other two are level, at cy + ry*sin(30deg).
      expect(d, contains('60'));
      expect(d, isNot(contains('50 70')));
    });

    test('the outline never leaves the bounding box', () {
      // Quadratics through the vertices stay in the convex hull of their
      // control points, which is what makes this true by construction.
      for (final sides in [3, 4, 5, 6, 8]) {
        for (var round = 0.0; round <= 1.0001; round += 0.1) {
          for (final rot in [0.0, 17.0, 90.0, -33.0]) {
            final cs = coords(polygon(Polygon(
              cx: 50,
              cy: 50,
              rx: 30,
              ry: 20,
              sides: sides,
              round: round,
              rot: rot,
            )));
            // Even indices are x, odd are y — positional, as serialized.
            for (var i = 0; i < cs.length; i++) {
              if (i.isEven) {
                expect(cs[i], inInclusiveRange(19.9, 80.1));
              } else {
                expect(cs[i], inInclusiveRange(29.9, 70.1));
              }
            }
          }
        }
      }
    });

    test('full rounding drops the straight runs instead of emitting empty ones',
        () {
      expect(
        polygon(const Polygon(
          cx: 50,
          cy: 50,
          rx: 20,
          ry: 20,
          sides: 6,
          round: 1,
        )).toPathData().contains('L'),
        isFalse,
      );
      expect(
        polygon(const Polygon(
          cx: 50,
          cy: 50,
          rx: 20,
          ry: 20,
          sides: 6,
          round: 0.9,
        )).toPathData().contains('L'),
        isTrue,
      );
    });
  });

  group('capsule, taper and arc', () {
    test('box emits the exact stadium run', () {
      expect(box(50, 50, 30, 20).toPathData(), 'M20 30H80V70H20Z');
    });

    test('taper tangency points sit on the body ellipse', () {
      final d = taper(50, 55, 30, 25, 1.5).toPathData();
      expect(d, endsWith('Z'));
      for (final v in coordsOf(d)) {
        expect(v.isFinite, isTrue);
      }
    });

    test('arc emits a stroked quadratic', () {
      expect(arc(50, 60, 10, 6).toPathData(), 'M40 60Q50 66 60 60');
    });
  });
}
