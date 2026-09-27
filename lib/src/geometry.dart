/// Structured geometry for hiblob figures.
///
/// The core never touches `dart:ui`. Shapes are built as [GeometryPath]s —
/// lists of plain commands with exact double coordinates — which serialize to
/// a stable string form (for tests and equality) and convert cheaply to
/// `ui.Path` in the Flutter layer.
library;

import 'dart:math' as math;

/// A point in the 100-by-100 view box.
typedef Pt = ({double x, double y});

/// One path command.
sealed class GeometryCommand {
  const GeometryCommand();
}

/// Jumps the pen to ([x], [y]) without drawing.
class MoveTo extends GeometryCommand {
  final double x;
  final double y;
  const MoveTo(this.x, this.y);
}

/// Draws a straight line to ([x], [y]).
class LineTo extends GeometryCommand {
  final double x;
  final double y;
  const LineTo(this.x, this.y);
}

/// Draws a cubic Bézier to ([x], [y]) with controls ([c1x], [c1y]) and
/// ([c2x], [c2y]).
class CubicTo extends GeometryCommand {
  final double c1x, c1y, c2x, c2y, x, y;
  const CubicTo(this.c1x, this.c1y, this.c2x, this.c2y, this.x, this.y);
}

/// Draws a quadratic Bézier to ([x], [y]) with control ([cx], [cy]).
class QuadraticTo extends GeometryCommand {
  final double cx, cy, x, y;
  const QuadraticTo(this.cx, this.cy, this.x, this.y);
}

/// Closes the current sub-path with a straight line back to its start.
class ClosePath extends GeometryCommand {
  const ClosePath();
}

/// One drawn primitive: an ordered command list, plus how it paints.
///
/// A path is either filled (the default) or stroked with [strokeWidth]. Two
/// paths are equal when their serialized form and paint mode are equal.
class GeometryPath {
  final List<GeometryCommand> commands;

  /// Whether this path is stroked rather than filled.
  final bool stroke;

  /// The stroke width in view-box units when [stroke] is set.
  final double strokeWidth;

  String? _data;

  GeometryPath(
    this.commands, {
    this.stroke = false,
    this.strokeWidth = 1.0,
  });

  /// A rounded, deterministic serialization of this path.
  String toPathData() {
    return _data ??= () {
      final b = StringBuffer();
      for (final c in commands) {
        switch (c) {
          case MoveTo(:final x, :final y):
            b.write('M${_fmt(x)} ${_fmt(y)}');
          case LineTo(:final x, :final y):
            b.write('L${_fmt(x)} ${_fmt(y)}');
          case CubicTo(
              :final c1x,
              :final c1y,
              :final c2x,
              :final c2y,
              :final x,
              :final y
            ):
            b.write('C${_fmt(c1x)} ${_fmt(c1y)} ${_fmt(c2x)} ${_fmt(c2y)} '
                '${_fmt(x)} ${_fmt(y)}');
          case QuadraticTo(:final cx, :final cy, :final x, :final y):
            b.write('Q${_fmt(cx)} ${_fmt(cy)} ${_fmt(x)} ${_fmt(y)}');
          case ClosePath():
            b.write('Z');
        }
      }
      return b.toString();
    }();
  }

  @override
  bool operator ==(Object other) =>
      other is GeometryPath &&
      other.stroke == stroke &&
      other.strokeWidth == strokeWidth &&
      other.toPathData() == toPathData();

  @override
  int get hashCode => Object.hash(toPathData(), stroke, strokeWidth);

  @override
  String toString() => toPathData();

  /// The conservative bounding box: every endpoint and control point.
  ({double minX, double minY, double maxX, double maxY}) get bounds {
    double minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    void add(double x, double y) {
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    for (final c in commands) {
      switch (c) {
        case MoveTo(:final x, :final y):
          add(x, y);
        case LineTo(:final x, :final y):
          add(x, y);
        case CubicTo(
            :final c1x,
            :final c1y,
            :final c2x,
            :final c2y,
            :final x,
            :final y
          ):
          add(c1x, c1y);
          add(c2x, c2y);
          add(x, y);
        case QuadraticTo(:final cx, :final cy, :final x, :final y):
          add(cx, cy);
          add(x, y);
        case ClosePath():
      }
    }
    return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }
}

Pt _normDir(double dx, double dy) {
  final len = math.sqrt(dx * dx + dy * dy);
  return len == 0 ? (x: 0.0, y: 0.0) : (x: dx / len, y: dy / len);
}

double _dist(Pt a, Pt b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

String _fmt(double v) => v.toStringAsFixed(2);

/// One radial perturbation of the organic silhouette: the radius wiggles by
/// [amplitude] (as a fraction of the base radius) over [harmonic] cycles,
/// shifted by [phase] radians.
class RadialWave {
  final int harmonic;
  final double amplitude;
  final double phase;
  const RadialWave(this.harmonic, this.amplitude, this.phase);
}

const double _k = 0.5522847498307936; // circle → cubic handle constant

/// Builds a circle centered at ([cx], [cy]) with radius [r].
GeometryPath circle(double cx, double cy, double r) => ellipse(cx, cy, r, r);

/// Builds an ellipse centered at ([cx], [cy]).
GeometryPath ellipse(double cx, double cy, double rx, double ry) {
  return GeometryPath([
    MoveTo(cx + rx, cy),
    CubicTo(cx + rx, cy + ry * _k, cx + rx * _k, cy + ry, cx, cy + ry),
    CubicTo(cx - rx * _k, cy + ry, cx - rx, cy + ry * _k, cx - rx, cy),
    CubicTo(cx - rx, cy - ry * _k, cx - rx * _k, cy - ry, cx, cy - ry),
    CubicTo(cx + rx * _k, cy - ry, cx + rx, cy - ry * _k, cx + rx, cy),
    const ClosePath(),
  ]);
}

/// Smooths a closed loop of points with Catmull-Rom → cubic Bézier conversion.
GeometryPath smoothClosed(List<Pt> pts) {
  assert(pts.length >= 3, 'a closed loop needs at least 3 points');
  final n = pts.length;
  final cmds = <GeometryCommand>[MoveTo(pts[0].x, pts[0].y)];
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n], p1 = pts[i];
    final p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    cmds.add(CubicTo(
      p1.x + (p2.x - p0.x) / 6,
      p1.y + (p2.y - p0.y) / 6,
      p2.x - (p3.x - p1.x) / 6,
      p2.y - (p3.y - p1.y) / 6,
      p2.x,
      p2.y,
    ));
  }
  cmds.add(const ClosePath());
  return GeometryPath(cmds);
}

/// Builds a superellipse (Lamé curve) — the boxy family.
///
/// [n] = 2 is an ellipse; larger exponents square the shoulders off. Sampled
/// at [samples] angles and smoothed.
GeometryPath superellipse(
  double cx,
  double cy,
  double rx,
  double ry,
  double n, {
  int samples = 48,
}) {
  final e = 2 / n;
  final pts = <Pt>[];
  for (var i = 0; i < samples; i++) {
    final t = 2 * math.pi * i / samples;
    final ct = math.cos(t), st = math.sin(t);
    final x = rx * _signedPow(ct, e);
    final y = ry * _signedPow(st, e);
    pts.add((x: cx + x, y: cy + y));
  }
  return smoothClosed(pts);
}

double _signedPow(double v, double e) {
  final s = v < 0 ? -1.0 : 1.0;
  return s * math.pow(v.abs(), e).toDouble();
}

/// Builds the organic silhouette: a circle whose radius wobbles by [waves].
GeometryPath radialBlob(
  double cx,
  double cy,
  double baseR,
  List<RadialWave> waves, {
  int samples = 32,
}) {
  final pts = <Pt>[];
  for (var i = 0; i < samples; i++) {
    final t = 2 * math.pi * i / samples;
    var r = baseR;
    for (final w in waves) {
      r += w.amplitude * baseR * math.cos(w.harmonic * t + w.phase);
    }
    pts.add((x: cx + r * math.cos(t), y: cy + r * math.sin(t)));
  }
  return smoothClosed(pts);
}

/// Builds a regular [sides]-gon with corners softened by [rounding]
/// (`0` = sharp, `< 0.5`; `0.5` approaches a circle).
GeometryPath roundedPolygon(
  double cx,
  double cy,
  double radius,
  int sides,
  double rounding, {
  double rotation = 0,
}) {
  assert(sides >= 3);
  final verts = <Pt>[];
  for (var i = 0; i < sides; i++) {
    final a = rotation + 2 * math.pi * i / sides;
    verts.add((x: cx + radius * math.cos(a), y: cy + radius * math.sin(a)));
  }
  final starts = <Pt>[], ends = <Pt>[];
  for (var i = 0; i < sides; i++) {
    final prev = verts[(i - 1 + sides) % sides], cur = verts[i];
    final next = verts[(i + 1) % sides];
    final d1 = _normDir(cur.x - prev.x, cur.y - prev.y);
    final d2 = _normDir(next.x - cur.x, next.y - cur.y);
    final cut =
        math.min(_dist(prev, cur), _dist(cur, next)) * rounding.clamp(0.0, 0.5);
    starts.add((x: cur.x - d1.x * cut, y: cur.y - d1.y * cut));
    ends.add((x: cur.x + d2.x * cut, y: cur.y + d2.y * cut));
  }
  final cmds = <GeometryCommand>[MoveTo(starts[0].x, starts[0].y)];
  for (var i = 0; i < sides; i++) {
    final next = (i + 1) % sides;
    cmds.add(QuadraticTo(verts[i].x, verts[i].y, ends[i].x, ends[i].y));
    cmds.add(LineTo(starts[next].x, starts[next].y));
  }
  cmds.add(const ClosePath());
  return GeometryPath(cmds);
}

/// Builds a rounded rectangle — a capsule when [r] is half the short side.
GeometryPath roundedRect(double cx, double cy, double w, double h, double r) {
  r = math.min(r, math.min(w, h) / 2);
  final k = r * _k;
  final l = cx - w / 2, t = cy - h / 2;
  final rt = cx + w / 2, b = cy + h / 2;
  return GeometryPath([
    MoveTo(l + r, t),
    LineTo(rt - r, t),
    CubicTo(rt - r + k, t, rt, t + r - k, rt, t + r),
    LineTo(rt, b - r),
    CubicTo(rt, b - r + k, rt - r + k, b, rt - r, b),
    LineTo(l + r, b),
    CubicTo(l + r - k, b, l, b - r + k, l, b - r),
    LineTo(l, t + r),
    CubicTo(l, t + r - k, l + r - k, t, l + r, t),
    const ClosePath(),
  ]);
}

/// Builds a soft [points]-point star — the sun silhouette.
///
/// Catmull-Rom smoothing rounds the spikes; the result reads as a chubby sun
/// rather than a jagged one.
GeometryPath star(
  double cx,
  double cy,
  double outerR,
  double innerR,
  int points, {
  double rotation = 0,
}) {
  final pts = <Pt>[];
  for (var i = 0; i < points * 2; i++) {
    final a = rotation + math.pi * i / points;
    final r = i.isEven ? outerR : innerR;
    pts.add((x: cx + r * math.cos(a), y: cy + r * math.sin(a)));
  }
  return smoothClosed(pts);
}

/// Builds the droplet silhouette: a round bulb with a soft point rising
/// [dropLen] above it.
GeometryPath droplet(double cx, double cy, double bulbR, double dropLen) {
  final tip = (x: cx, y: cy - bulbR - dropLen);
  final bend = bulbR * 0.62;
  return GeometryPath([
    MoveTo(tip.x, tip.y),
    CubicTo(
      tip.x - bend,
      tip.y + bend,
      cx - bulbR,
      cy - bulbR * 0.95,
      cx - bulbR,
      cy,
    ),
    CubicTo(
      cx - bulbR,
      cy + bulbR * _k,
      cx - bulbR * _k,
      cy + bulbR,
      cx,
      cy + bulbR,
    ),
    CubicTo(
      cx + bulbR * _k,
      cy + bulbR,
      cx + bulbR,
      cy + bulbR * _k,
      cx + bulbR,
      cy,
    ),
    CubicTo(
      cx + bulbR,
      cy - bulbR * 0.95,
      tip.x + bend,
      tip.y + bend,
      tip.x,
      tip.y,
    ),
    const ClosePath(),
  ]);
}

/// Builds a half disc — a filled semicircle with its flat side horizontal.
///
/// [down] bulges the arc downward (a smile-like shape); otherwise upward.
GeometryPath halfDisc(double x, double y, double r, {bool down = true}) {
  final dir = down ? 1.0 : -1.0;
  return GeometryPath([
    MoveTo(x - r, y),
    CubicTo(x - r, y + dir * r * _k, x - r * _k, y + dir * r, x, y + dir * r),
    CubicTo(x + r * _k, y + dir * r, x + r, y + dir * r * _k, x + r, y),
    const ClosePath(),
  ]);
}

/// Builds an open polyline stroked with [width] and round caps — the closed
/// and squinting eye shapes.
GeometryPath polyline(List<Pt> pts, {double width = 1.7}) {
  assert(pts.length >= 2);
  final cmds = <GeometryCommand>[MoveTo(pts[0].x, pts[0].y)];
  for (var i = 1; i < pts.length; i++) {
    cmds.add(LineTo(pts[i].x, pts[i].y));
  }
  return GeometryPath(cmds, stroke: true, strokeWidth: width);
}

/// Builds a filled quadrilateral — the slanted mad-eye shape.
GeometryPath quad(Pt a, Pt b, Pt c, Pt d) => GeometryPath([
      MoveTo(a.x, a.y),
      LineTo(b.x, b.y),
      LineTo(c.x, c.y),
      LineTo(d.x, d.y),
      const ClosePath(),
    ]);

/// Rotates ([x], [y]) around ([cx], [cy]) by [angle] radians.
Pt rotatePt(double x, double y, double cx, double cy, double angle) {
  final dx = x - cx, dy = y - cy;
  final cos = math.cos(angle), sin = math.sin(angle);
  return (x: cx + dx * cos - dy * sin, y: cy + dx * sin + dy * cos);
}
