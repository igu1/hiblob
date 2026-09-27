/// The silhouette vocabulary.
///
/// Silhouette definitions.
///
/// A shape is everything the layout needs to draw one silhouette and nothing
/// about when to draw it: how much of the frame its core body takes, how it
/// patches that body, what room it leaves the eyes, what it decorates with,
/// and which path primitive traces it. What it deliberately does *not* carry
/// is its threshold — how often it comes up is a property of the band table,
/// not of the silhouette itself. See `blob.dart`.
library;

import 'dart:math' as math;

import '../shape.dart';
import '../traits.dart';

/// The core body the shape draws and patches.
class Body {
  double cx;
  double cy;
  double rx;
  double ry;
  double n;
  double rot;
  List<double> radii;

  /// Polygon-only, set by the shapes that draw one.
  int? sides;
  double? round;

  Body({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.n,
    required this.rot,
    required this.radii,
    this.sides,
    this.round,
  });
}

/// An ellipse-shaped region: the face, or a decoration's cap.
class Ellipse {
  double cx;
  double cy;
  double rx;
  double ry;
  Ellipse(this.cx, this.cy, this.rx, this.ry);
}

/// A circle decoration unioned with the body (petals, caps, lobes, sun rays).
class Petal {
  final double cx;
  final double cy;
  final double r;
  const Petal(this.cx, this.cy, this.r);
}

/// What a shape's decorate hook accumulates.
class Deco {
  final List<Petal> petals = [];
  final List<BlobPath> extra = [];
}

/// One silhouette.
abstract class Shape {
  final String name;

  /// How much of the frame the core body takes.
  final double core;

  const Shape(this.name, this.core);

  /// Patches the body before the face is measured.
  void body(Traits t, Body b) {}

  /// The region the eyes must fit inside. Omitted, it is the body itself —
  /// which is what every silhouette that is convex around its own centre
  /// wants, and half the roster is.
  Ellipse? face(Body b) => null;

  void decorate(Traits t, Body b, Deco out) {}

  /// The core path. Omitted, `superellipse` — free to default to, because the
  /// eyes are superellipses too, so it is in every bundle already.
  BlobPath? path(Body b) => null;
}

// ---------------------------------------------------------------------------
// The shared implementations. Five path calls serve all ten shapes.

BlobPath _poly(Body b) => polygon(Polygon(
      cx: b.cx,
      cy: b.cy,
      rx: b.rx,
      ry: b.ry,
      sides: b.sides!,
      round: b.round!,
      rot: b.rot,
    ));

BlobPath _spline(Body b) => blobPath(b.cx, b.cy, b.rx, b.ry, b.radii, b.rot);

Ellipse _shrunk(Body b, double k) => Ellipse(b.cx, b.cy, b.rx * k, b.ry * k);

Ellipse _splineFace(Body b) {
  double min = b.radii[0];
  for (final double r in b.radii) {
    if (r < min) min = r;
  }
  return _shrunk(b, min * 0.95);
}

// ---------------------------------------------------------------------------

/// The everyday shape. n~4 squircle, everything per seed.
class RoundShape extends Shape {
  const RoundShape() : super('round', 1);
}

/// The hand-drawn pebble.
class OrganicShape extends Shape {
  const OrganicShape() : super('organic', 0.98);

  @override
  BlobPath path(Body b) => _spline(b);

  @override
  Ellipse face(Body b) => _splineFace(b);
}

/// `round`, squared off and tilted. Same path, different parameters.
class BoxyShape extends Shape {
  const BoxyShape() : super('boxy', 0.86);

  @override
  void body(Traits t, Body b) {
    b.n = t.numIn('body.n', 3.4, 6);
    b.rot = t.numIn('body.rot', -20, 20);
  }
}

class CapsuleShape extends Shape {
  const CapsuleShape() : super('capsule', 1.02);

  @override
  void body(Traits t, Body b) {
    b.ry *= t.numIn('capsule.squat', 0.55, 0.68);
  }

  @override
  Ellipse face(Body b) => _shrunk(b, 0.94);

  @override
  void decorate(Traits t, Body b, Deco out) {
    for (final int s in [-1, 1]) {
      out.petals.add(Petal(b.cx + s * (b.rx - b.ry), b.cy, b.ry));
    }
  }

  @override
  BlobPath path(Body b) => box(b.cx, b.cy, b.rx - b.ry, b.ry);
}

class NubShape extends Shape {
  const NubShape() : super('nub', 0.88);

  @override
  void decorate(Traits t, Body b, Deco out) {
    final int count = t.intIn('nub.n', 1, 2);
    for (var i = 0; i < count; i++) {
      final double a = t.numIn('nub.a$i', 0, 2 * math.pi);
      out.petals.add(Petal(
        b.cx + math.cos(a) * b.rx * 0.88,
        b.cy + math.sin(a) * b.rx * 0.88,
        b.rx * t.numIn('nub.r$i', 0.24, 0.4),
      ));
    }
  }
}

/// `organic`, with lobes on the upper half.
class CloudShape extends Shape {
  const CloudShape() : super('cloud', 0.78);

  @override
  BlobPath path(Body b) => _spline(b);

  @override
  Ellipse face(Body b) => _splineFace(b);

  @override
  void decorate(Traits t, Body b, Deco out) {
    final int count = t.intIn('cloud.n', 4, 6);
    for (var i = 0; i < count; i++) {
      final double a = math.pi + (math.pi * (i + 0.5)) / count;
      out.petals.add(Petal(
        b.cx + math.cos(a) * b.rx * 0.8,
        b.cy + math.sin(a) * b.rx * 0.5,
        b.rx * t.numIn('cloud.r$i', 0.44, 0.62),
      ));
    }
  }
}

class DropletShape extends Shape {
  const DropletShape() : super('droplet', 0.78);

  @override
  void body(Traits t, Body b) {
    // Shifted down by what the taper adds above, so the whole silhouette —
    // head and point together — sits centred in the frame rather than the head
    // alone. `n` is pinned to a true ellipse, which is the curve the taper is
    // tangent to.
    b.cy += 0.22 * b.ry;
    b.n = 2;
  }

  @override
  Ellipse face(Body b) =>
      Ellipse(b.cx, b.cy + b.ry * 0.05, b.rx * 0.88, b.ry * 0.88);

  @override
  void decorate(Traits t, Body b, Deco out) {
    out.extra
        .add(taper(b.cx, b.cy, b.rx, b.ry, t.numIn('droplet.tip', 1.4, 1.65)));
  }
}

class HexagonShape extends Shape {
  const HexagonShape() : super('hexagon', 1.05);

  @override
  BlobPath path(Body b) => _poly(b);

  @override
  Ellipse face(Body b) => _shrunk(b, 0.84);

  @override
  void body(Traits t, Body b) {
    b.sides = 6;
    b.rot = t.numIn('body.rot', -12, 12);
    b.round = t.numIn('poly.round', 0.24, 0.5);
  }
}

class SunShape extends Shape {
  const SunShape() : super('sun', 0.7);

  @override
  void decorate(Traits t, Body b, Deco out) {
    final int count = t.intIn('sun.n', 6, 9);
    final double dist = b.rx * t.numIn('sun.dist', 1.0, 1.08);
    final double pr = b.rx * t.numIn('sun.r', 0.2, 0.26);
    final double off = t.numIn('sun.rot', 0, 2 * math.pi);
    for (var i = 0; i < count; i++) {
      final double a = off + (2 * math.pi * i) / count;
      out.petals
          .add(Petal(b.cx + math.cos(a) * dist, b.cy + math.sin(a) * dist, pr));
    }
  }
}

/// `hexagon` with three sides, and a tighter tilt so it rests on its base.
class TriangleShape extends Shape {
  const TriangleShape() : super('triangle', 1.15);

  @override
  BlobPath path(Body b) => _poly(b);

  @override
  void body(Traits t, Body b) {
    b.sides = 3;
    b.rot = t.numIn('body.rot', -5, 5);
    b.round = t.numIn('poly.round', 0.24, 0.5);
  }

  @override
  Ellipse face(Body b) =>
      Ellipse(b.cx, b.cy + b.ry * 0.1, b.rx * 0.54, b.ry * 0.36);
}

const RoundShape round = RoundShape();
const OrganicShape organic = OrganicShape();
const BoxyShape boxy = BoxyShape();
const CapsuleShape capsule = CapsuleShape();
const NubShape nub = NubShape();
const CloudShape cloud = CloudShape();
const DropletShape droplet = DropletShape();
const HexagonShape hexagon = HexagonShape();
const SunShape sun = SunShape();
const TriangleShape triangle = TriangleShape();
