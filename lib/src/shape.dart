/// The path primitives.
///
/// Geometry primitives for the hiblob engine.
///
/// The primitives emit structured segments ([BlobPath]) rather than SVG path
/// strings, so the Flutter painter in a later phase can consume geometry
/// directly. [BlobPath.toPathData] serializes to exactly the strings the
/// engine emits (same rounding, same compact syntax), which
/// is what the cross-language reference vectors assert against.
library;

import 'dart:math' as math;

/// One path command. Absolute commands only — that is all this library emits.
sealed class PathSegment {
  const PathSegment();
}

class MoveTo extends PathSegment {
  final double x;
  final double y;
  const MoveTo(this.x, this.y);
}

class LineTo extends PathSegment {
  final double x;
  final double y;
  const LineTo(this.x, this.y);
}

class CubicTo extends PathSegment {
  final double c1x, c1y, c2x, c2y, x, y;
  const CubicTo(this.c1x, this.c1y, this.c2x, this.c2y, this.x, this.y);
}

class QuadTo extends PathSegment {
  final double cx, cy, x, y;
  const QuadTo(this.cx, this.cy, this.x, this.y);
}

class HorizontalLineTo extends PathSegment {
  final double x;
  const HorizontalLineTo(this.x);
}

class VerticalLineTo extends PathSegment {
  final double y;
  const VerticalLineTo(this.y);
}

class ClosePath extends PathSegment {
  const ClosePath();
}

/// JS `Math.round` — half toward positive infinity.
double jsRound(double v) => (v + 0.5).floorToDouble();

/// The `r2` formatter: two decimal places, `-0` collapsed to `0`, and no
/// trailing `.0` on whole numbers — byte-identical to JS `String(Number)`.
String r2(double v) {
  final double s = jsRound(v * 100) / 100;
  if (s == 0) return '0';
  if (s.truncateToDouble() == s) return s.truncate().toString();
  return s.toString();
}

/// A structured closed/open path with a faithful string serialization.
class BlobPath {
  final List<PathSegment> segments;

  const BlobPath(this.segments);

  /// The SVG path data, in exactly the form the geometry core emits:
  /// compact command letters, single-space-separated coordinates, two-decimal
  /// rounding.
  String toPathData() {
    final d = StringBuffer();
    for (final PathSegment seg in segments) {
      switch (seg) {
        case MoveTo(:final x, :final y):
          d.write('M${r2(x)} ${r2(y)}');
        case LineTo(:final x, :final y):
          d.write('L${r2(x)} ${r2(y)}');
        case CubicTo(
            :final c1x,
            :final c1y,
            :final c2x,
            :final c2y,
            :final x,
            :final y
          ):
          d.write(
            'C${r2(c1x)} ${r2(c1y)} ${r2(c2x)} ${r2(c2y)} ${r2(x)} ${r2(y)}',
          );
        case QuadTo(:final cx, :final cy, :final x, :final y):
          d.write('Q${r2(cx)} ${r2(cy)} ${r2(x)} ${r2(y)}');
        case HorizontalLineTo(:final x):
          d.write('H${r2(x)}');
        case VerticalLineTo(:final y):
          d.write('V${r2(y)}');
        case ClosePath():
          d.write('Z');
      }
    }
    return d.toString();
  }
}

/// A superellipse: `|x/a|^n + |y/b|^n = 1`.
///
/// |x/a|^n + |y/b|^n = 1 covers the whole part vocabulary: n=2 is an ellipse
/// (eyes, pupils), n~4 a squircle (head, background), n->large a rectangle
/// (brows, mouth lines). One shape function, one continuous knob, so "head
/// shape" is a numeric trait rather than a set of hand-drawn alternatives.
class Superellipse {
  final double cx, cy, rx, ry;
  final double n;
  final double rot;

  const Superellipse({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    this.n = 4,
    this.rot = 0,
  });
}

/// Approximates each quadrant of a superellipse with one cubic Bezier.
///
/// The control offset is chosen so the curve passes exactly through the
/// superellipse's 45-degree point: B(0.5) = a(4+3k)/8 must equal a*2^(-1/n).
/// At n=2 this yields 0.5523 — the standard circle constant — which is a good
/// sign the derivation is right. Four segments instead of a 24-point sampled
/// polyline keeps each shape at ~130 bytes of path data.
BlobPath superellipse(Superellipse s) {
  final double cx = s.cx, cy = s.cy, rx = s.rx, ry = s.ry;
  final double n = s.n, rot = s.rot;
  // Above n~5.55 the control offset exceeds the radius, and the curve bulges
  // outside the bounding box instead of squaring off — an inflated-looking
  // corner rather than a sharper one. Clamping k trades exactness at the 45deg
  // point for a shape that always stays within its stated bounds.
  final double k = math.min(1.0, (8 * math.pow(2, -1 / n) - 4) / 3);
  final double a = rx;
  final double b = ry;
  final double ak = a * k;
  final double bk = b * k;

  // Anchor, control, control — walking the four quadrants.
  final pts = <(double, double)>[
    (a, 0),
    (a, bk),
    (ak, b),
    (0, b),
    (-ak, b),
    (-a, bk),
    (-a, 0),
    (-a, -bk),
    (-ak, -b),
    (0, -b),
    (ak, -b),
    (a, -bk),
    (a, 0),
  ];

  final double t = rot * math.pi / 180;
  final double cos = math.cos(t);
  final double sin = math.sin(t);
  (double, double) at(int i) {
    final (double x, double y) = pts[i];
    return (cx + x * cos - y * sin, cy + x * sin + y * cos);
  }

  final segments = <PathSegment>[];
  final (double x0, double y0) = at(0);
  segments.add(MoveTo(x0, y0));
  for (var i = 1; i < 13; i += 3) {
    final (double c1x, double c1y) = at(i);
    final (double c2x, double c2y) = at(i + 1);
    final (double px, double py) = at(i + 2);
    segments.add(CubicTo(c1x, c1y, c2x, c2y, px, py));
  }
  segments.add(const ClosePath());
  return BlobPath(segments);
}

/// A quadratic arc, stroked — used only for smiles and frowns, where a closed
/// superellipse would need a boolean subtraction to get the same read.
BlobPath arc(double cx, double cy, double w, double depth) => BlobPath([
      MoveTo(cx - w, cy),
      QuadTo(cx, cy + depth, cx + w, cy),
    ]);

/// An organic closed curve: radii sampled around a circle, joined by a closed
/// Catmull-Rom spline converted to cubic Beziers.
///
/// The superellipse handles everything symmetric; this handles everything that
/// needs to look hand-drawn. `radii` are multipliers of the base radius, one
/// per vertex, so a seed perturbing them produces the lopsided pebble shapes
/// without any noise function — the vertex count alone controls how lumpy it
/// is.
///
/// Catmull-Rom rather than a Bezier fit because it interpolates its points
/// exactly, so the radii mean what they say and containment stays predictable.
BlobPath blobPath(
  double cx,
  double cy,
  double rx,
  double ry,
  List<double> radii, [
  double rot = 0,
]) {
  final int n = radii.length;
  final double t0 = rot * math.pi / 180;
  final p = <(double, double)>[
    for (var i = 0; i < n; i++)
      (
        cx + rx * radii[i] * math.cos(t0 + 2 * math.pi * i / n),
        cy + ry * radii[i] * math.sin(t0 + 2 * math.pi * i / n),
      ),
  ];

  (double, double) at(int i) => p[((i % n) + n) % n];

  final segments = <PathSegment>[];
  final (double sx, double sy) = at(0);
  segments.add(MoveTo(sx, sy));

  for (var i = 0; i < n; i++) {
    final (double x0, double y0) = at(i - 1);
    final (double x1, double y1) = at(i);
    final (double x2, double y2) = at(i + 1);
    final (double x3, double y3) = at(i + 2);
    segments.add(CubicTo(
      x1 + (x2 - x0) / 6,
      y1 + (y2 - y0) / 6,
      x2 - (x3 - x1) / 6,
      y2 - (y3 - y1) / 6,
      x2,
      y2,
    ));
  }

  segments.add(const ClosePath());
  return BlobPath(segments);
}

/// A regular polygon with rounded corners.
///
/// The third primitive, and it is here because neither of the other two
/// reaches a flat-sided shape. Corners are cut back along both adjoining edges
/// by `round` and joined with a quadratic through the vertex itself, which
/// puts the whole outline inside the polygon's convex hull for free: a
/// quadratic never leaves the triangle of its three points.
///
/// `rx` and `ry` are the circumradius on each axis, so the shape squashes with
/// the body like everything else here rather than staying stubbornly regular.
class Polygon {
  final double cx, cy, rx, ry;
  final int sides;

  /// Corner rounding, 0 (sharp) to 1 (every edge cut back to its own
  /// midpoint, so the outline is all curve and no straight run).
  final double round;

  /// Degrees, clockwise. 0 puts a vertex at the top.
  final double rot;

  const Polygon({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.sides,
    this.round = 0.3,
    this.rot = 0,
  });
}

BlobPath polygon(Polygon p) {
  final double cx = p.cx, cy = p.cy, rx = p.rx, ry = p.ry;
  final int sides = p.sides;
  final double round = p.round, rot = p.rot;
  // Halved because the cut is taken from both ends of every edge: at round = 1
  // each end reaches the midpoint and they meet exactly, so anything above
  // that would have the two cuts cross and the outline fold back on itself.
  final double k = round > 0 ? (round < 1 ? round / 2 : 0.5) : 0;
  // -90deg so a vertex sits at the top: a triangle points up and rests on a
  // flat edge, which is the orientation anybody who asks for a triangle means.
  final double t0 = rot * math.pi / 180 - math.pi / 2;
  final v = <(double, double)>[
    for (var i = 0; i < sides; i++)
      (
        cx + rx * math.cos(t0 + 2 * math.pi * i / sides),
        cy + ry * math.sin(t0 + 2 * math.pi * i / sides),
      ),
  ];

  (double, double) at(int i) => v[((i % sides) + sides) % sides];

  /// The cut point on the edge leaving vertex `i` toward vertex `j`.
  (double, double) cut(int i, int j) {
    final (double x0, double y0) = at(i);
    final (double x1, double y1) = at(j);
    return (x0 + (x1 - x0) * k, y0 + (y1 - y0) * k);
  }

  final segments = <PathSegment>[];
  final (double m0x, double m0y) = cut(0, -1);
  segments.add(MoveTo(m0x, m0y));
  for (var i = 0; i < sides; i++) {
    final (double vx, double vy) = at(i);
    final (double ex, double ey) = cut(i, i + 1);
    segments.add(QuadTo(vx, vy, ex, ey));
    // The straight run to the next corner's cut. Omitted when the cuts meet,
    // so a fully rounded polygon does not emit `sides` zero-length lines.
    if (k < 0.5) {
      final (double lx, double ly) = cut(i + 1, i);
      segments.add(LineTo(lx, ly));
    }
  }
  segments.add(const ClosePath());
  return BlobPath(segments);
}

/// The straight run of a capsule, as a plain box.
///
/// Drawn with the two cap circles the capsule already decorates with, the
/// union is an exact stadium: the box reaches full height everywhere, so each
/// cap meets it along its own diameter and there is no crease.
BlobPath box(double cx, double cy, double rx, double ry) => BlobPath([
      MoveTo(cx - rx, cy - ry),
      HorizontalLineTo(cx + rx),
      VerticalLineTo(cy + ry),
      HorizontalLineTo(cx - rx),
      const ClosePath(),
    ]);

/// The taper of a droplet: the two tangents from an apex to the body ellipse.
///
/// Drawn with that ellipse, the union is a teardrop. A tangent meets the curve
/// without a corner, so the taper grows out of the head at every `tip` rather
/// than being stuck on. `tip` is how far the apex sits above the centre in
/// units of `ry`, and so also how far down the sides the flanks take hold.
///
/// The point is eased with a quadratic through the apex, so the drawn tip
/// stops just short of it — no needle at small sizes, and `tip` bounds the
/// silhouette rather than touching it.
BlobPath taper(double cx, double cy, double rx, double ry, double tip) {
  // In the circle the ellipse is an affine image of, the tangent points sit at
  // angle acos(1/tip) from the apex direction. Affine maps preserve tangency,
  // so scaling those two points by rx and ry is exact, not an approximation.
  final double t = math.max(1.05, tip);
  final double tx = rx * math.sqrt(1 - 1 / (t * t));
  final double ty = cy - ry / t;
  final double apex = cy - t * ry;
  // How far up each flank the eased point takes over. Small, so the flanks
  // stay straight enough to read as a taper.
  final double px = tx * 0.14;
  final double py = ty + 0.86 * (apex - ty);
  return BlobPath([
    MoveTo(cx - tx, ty),
    LineTo(cx - px, py),
    QuadTo(cx, apex, cx + px, py),
    LineTo(cx + tx, ty),
    const ClosePath(),
  ]);
}
