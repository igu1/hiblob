import 'dart:math' as math;

import 'package:test/test.dart';

import 'package:hiblob/hiblob.dart';

/// Dart port of the containment invariants in
/// `packages/hiblob/test/geometry.test.ts` — the frame guarantee, the
/// face-honesty guarantee, and the same invariants under trait overrides.
///
/// These are the checks that reject broken geometry regardless of what any
/// cross-language fixture says: the containment guarantees are part of the
/// port's contract.
void main() {
  const seedCount = 6000;
  final layouts = [
    for (var i = 0; i < seedCount; i++) style.layout(traitsFor('seed-$i')),
  ];

  double inside(double px, double py, Ellipse s, double n) =>
      (math.pow(((px - s.cx) / s.rx).abs(), n) +
              math.pow(((py - s.cy) / s.ry).abs(), n))
          .toDouble();

  List<(double, double)> corners(Eye e) {
    final double t = e.rot * math.pi / 180;
    final double c = math.cos(t);
    final double s = math.sin(t);
    return [
      for (final (int sx, int sy) in [(1, 1), (1, -1), (-1, 1), (-1, -1)])
        (
          e.cx + sx * e.rx * c - sy * e.ry * s,
          e.cy + sx * e.rx * s + sy * e.ry * c,
        ),
    ];
  }

  /// The rounded polygon's cut points, which the drawn outline strictly
  /// contains.
  List<(double, double)> cutHull(Body b) {
    final double k = b.round! > 0 ? (b.round! < 1 ? b.round! / 2 : 0.5) : 0;
    final double t0 = b.rot * math.pi / 180 - math.pi / 2;
    final sides = b.sides!;
    final v = <(double, double)>[
      for (var i = 0; i < sides; i++)
        (
          b.cx + b.rx * math.cos(t0 + 2 * math.pi * i / sides),
          b.cy + b.ry * math.sin(t0 + 2 * math.pi * i / sides),
        ),
    ];
    (double, double) at(int i) => v[((i % sides) + sides) % sides];
    final out = <(double, double)>[];
    for (var i = 0; i < sides; i++) {
      for (final int j in [i - 1, i + 1]) {
        final (double x0, double y0) = at(i);
        final (double x1, double y1) = at(j);
        out.add((x0 + (x1 - x0) * k, y0 + (y1 - y0) * k));
      }
    }
    // Angular sort, so the cut points come back as a traversable convex
    // polygon rather than in vertex-pair order.
    out.sort((a, c) => (math.atan2(a.$2 - b.cy, a.$1 - b.cx))
        .compareTo(math.atan2(c.$2 - b.cy, c.$1 - b.cx)));
    return out;
  }

  bool inConvex(double px, double py, List<(double, double)> poly) {
    var neg = false;
    var pos = false;
    for (var i = 0; i < poly.length; i++) {
      final (double x0, double y0) = poly[i];
      final (double x1, double y1) = poly[(i + 1) % poly.length];
      final double cross = (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0);
      if (cross > 1e-9) pos = true;
      if (cross < -1e-9) neg = true;
    }
    return !(pos && neg);
  }

  /// Distance from a point to the segment joining a capsule's two cap centres.
  double toSpine(double px, double py, HiblobLayout l) {
    final double half = l.body.rx - l.body.ry;
    final double dx = math.max(0, (px - l.body.cx).abs() - half);
    return math.sqrt(dx * dx + (py - l.body.cy) * (py - l.body.cy));
  }

  /// Whether a point is inside the drawn silhouette. Conservative everywhere:
  /// the shapes that union extra parts are tested against the core alone, and
  /// the spline shapes against their smallest sampled radius.
  bool inBody(double px, double py, HiblobLayout l) {
    final b = l.body;
    if (l.shape == 'triangle' || l.shape == 'hexagon') {
      return inConvex(px, py, cutHull(b));
    }
    if (l.shape == 'capsule') return toSpine(px, py, l) <= b.ry;
    final double shrink =
        l.shape == 'organic' || l.shape == 'cloud' ? _min(b.radii) * 0.95 : 1;
    // Squareness is understated and tilt is not: a boxy body is squarer than
    // n: 2 and so roomier, but a body whose seeded n falls under 2 is drawn
    // *inside* that ellipse, and measuring it against one was the model
    // claiming room the shape does not have.
    final double t = -b.rot * math.pi / 180;
    final double dx = px - b.cx;
    final double dy = py - b.cy;
    return inside(
          b.cx + dx * math.cos(t) - dy * math.sin(t),
          b.cy + dx * math.sin(t) + dy * math.cos(t),
          Ellipse(b.cx, b.cy, b.rx * shrink, b.ry * shrink),
          math.min(b.n, 2),
        ) <
        1;
  }

  void checkEyes(Iterable<HiblobLayout> ls) {
    for (final l in ls) {
      for (final e in l.eyes) {
        for (final (double x, double y) in corners(e)) {
          // First against the face, which is what the layout's fit promises...
          expect(inside(x, y, l.face, 2), lessThan(1),
              reason: '${l.shape} eye corner ($x, $y) outside face');
          // ...and then against the silhouette itself, which is what the face
          // is only a claim about.
          expect(inBody(x, y, l), isTrue,
              reason: '${l.shape} eye corner ($x, $y) outside body');
        }
      }
    }
  }

  group('frame', () {
    test('all geometry stays inside the viewBox', () {
      var checked = 0;
      for (final l in layouts) {
        final paths = [l.bodyPath(), ...l.eyePaths(), ...l.extra];
        for (final p in paths) {
          for (final v in _coords(p)) {
            expect(v, inInclusiveRange(-0.01, 100.01),
                reason: '${l.shape} coordinate $v out of frame');
            checked++;
          }
        }
        for (final p in l.petals) {
          expect(p.cx - p.r, greaterThanOrEqualTo(-0.01));
          expect(p.cx + p.r, lessThanOrEqualTo(100.01));
          expect(p.cy - p.r, greaterThanOrEqualTo(-0.01));
          expect(p.cy + p.r, lessThanOrEqualTo(100.01));
          checked++;
        }
      }
      expect(checked, greaterThan(0));
    });
  });

  group('blob', () {
    test('eyes sit inside the face, and the face inside the body', () {
      checkEyes(layouts);
    });

    test('eyes never fuse into each other', () {
      for (final l in layouts) {
        final a = l.eyes[0];
        final b = l.eyes[1];
        double reach(Eye e) {
          final double t = e.rot * math.pi / 180;
          return (e.rx * math.cos(t)).abs() + (e.ry * math.sin(t)).abs();
        }

        expect((b.cx - a.cx).abs(), greaterThan(reach(a) + reach(b)),
            reason: '${l.shape} eyes overlap');
      }
    });

    test('decoration stays attached to the body', () {
      for (final l in layouts) {
        for (final p in l.petals) {
          final double d = _hypot(p.cx - l.body.cx, p.cy - l.body.cy);
          expect(d, lessThan(l.body.rx * 0.95 + p.r),
              reason: '${l.shape} petal adrift');
        }
        // The droplet's taper is the one part meant to leave the core, so it
        // is checked the other way round: it starts at a tangent point, which
        // has to sit *on* the body ellipse — and the body it hangs off stays a
        // true ellipse rather than a squarer one.
        for (final extra in l.extra) {
          final seg = extra.segments.first as MoveTo;
          final double on = inside(seg.x, seg.y,
              Ellipse(l.body.cx, l.body.cy, l.body.rx, l.body.ry), 2);
          expect((on - 1).abs(), lessThan(0.01),
              reason: '${l.shape} taper start off the ellipse');
          expect(l.body.n, 2);
        }
      }
    });

    test('every shape in the vocabulary is reachable', () {
      final names = layouts.map((l) => l.shape).toSet();
      expect(
        names,
        containsAll([
          'round',
          'organic',
          'boxy',
          'nub',
          'cloud',
          'sun',
          'capsule',
          'triangle',
          'hexagon',
          'droplet',
        ]),
      );
      expect(names.length, 10);
    });

    test('the everyday shapes stay everyday and the loud ones stay rare', () {
      double share(String s) =>
          layouts.where((l) => l.shape == s).length / layouts.length;
      expect(share('round') + share('organic'), greaterThan(0.4));
      expect(share('triangle'), lessThan(0.04));
      expect(
          share('sun') + share('hexagon') + share('droplet'), lessThan(0.16));
    });
  });

  group('under trait overrides', () {
    /// Every trait key gen-2 reads, hand-written like the TS test's list.
    const keys = [
      'shape',
      'hue',
      'tone',
      'body.r',
      'body.ratio',
      'body.x',
      'body.y',
      'body.n',
      'body.rot',
      'body.pts',
      'body.r0',
      'body.r1',
      'body.r2',
      'body.r3',
      'body.r4',
      'body.r5',
      'body.r6',
      'body.r7',
      'gaze.x',
      'gaze.y',
      'eye.rx',
      'eye.ratio',
      'eye.scale',
      'eye.stretch',
      'eye.gap',
      'eye.n',
      'eye.lean',
      'eye.lean2',
      'eye.dy',
      'sun.n',
      'sun.dist',
      'sun.r',
      'sun.rot',
      'cloud.n',
      'cloud.r0',
      'cloud.r1',
      'cloud.r2',
      'cloud.r3',
      'cloud.r4',
      'cloud.r5',
      'nub.n',
      'nub.a0',
      'nub.a1',
      'nub.r0',
      'nub.r1',
      'poly.round',
      'capsule.squat',
      'droplet.tip',
    ];

    final maps = <Map<String, Object>>[];
    for (final v in [0.0, 0.5, 0.999999]) {
      final all = {for (final k in keys) k: v};
      maps.add(all);
      for (final k in keys) {
        maps
          ..add({...all, k: 0.0})
          ..add({...all, k: 0.999999});
      }
    }
    // Every shape band crossed with those extremes, since one `shape` value
    // per map would otherwise leave eight of the ten silhouettes untested.
    for (final at in [
      0.1,
      0.35,
      0.55,
      0.65,
      0.75,
      0.82,
      0.89,
      0.93,
      0.96,
      0.99
    ]) {
      for (final v in [0.0, 0.5, 0.999999]) {
        maps.add({for (final k in keys) k: v, 'shape': at});
      }
    }
    var s = 1;
    for (var i = 0; i < 400; i++) {
      final m = <String, Object>{};
      for (final k in keys) {
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF;
        m[k] = s / 4294967296;
      }
      maps.add(m);
    }

    test('the override sweep stays inside the face, body and frame', () {
      final cfgs = [
        for (final m in maps) style.layout(traitsFor('cfg', overrides: m)),
      ];
      checkEyes(cfgs);
      for (final l in cfgs) {
        final paths = [l.bodyPath(), ...l.eyePaths(), ...l.extra];
        for (final p in paths) {
          for (final v in _coords(p)) {
            expect(v, inInclusiveRange(-0.01, 100.01),
                reason: '${l.shape} coordinate $v out of frame');
          }
        }
        for (final p in l.petals) {
          expect(p.cx - p.r, greaterThanOrEqualTo(-0.01));
          expect(p.cx + p.r, lessThanOrEqualTo(100.01));
          expect(p.cy - p.r, greaterThanOrEqualTo(-0.01));
          expect(p.cy + p.r, lessThanOrEqualTo(100.01));
        }
      }
    });
  });
}

double _hypot(double x, double y) => math.sqrt(x * x + y * y);

List<double> _coords(BlobPath p) {
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

double _min(List<double> xs) {
  var m = xs[0];
  for (final x in xs) {
    if (x < m) m = x;
  }
  return m;
}
