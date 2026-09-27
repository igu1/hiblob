/// A Hiblob style composed from silhouette definitions.
///
/// The composed figure: bands, fit, and the frozen seed-to-look mapping.
///
/// The band table chooses and weights silhouettes. Each silhouette owns its
/// geometry and safe face region; this module owns the shared body, the eye
/// fitting, and the containment arithmetic. The seam is private, so it can
/// deepen when a future shape proves the current definition insufficient.
library;

import 'dart:math' as math;

import '../shape.dart';
import '../traits.dart';
import 'shapes.dart';

/// One fitted eye.
class Eye {
  double cx;
  double cy;
  double rx;
  double ry;
  double n;
  double rot;
  Eye(this.cx, this.cy, this.rx, this.ry, this.n, this.rot);
}

/// The resolved layout for one seed: everything a renderer needs and nothing
/// about how to serialize it.
class HiblobLayout {
  final String shape;
  final Body body;
  final Ellipse face;
  final List<Eye> eyes;
  final List<Petal> petals;
  final List<BlobPath> extra;
  final double bodyOffsetY;

  /// The shape's core-path hook, kept as a function for parity with the
  /// renderer so it is traced against the body's live values at draw time.
  /// Returns null for shapes that name no path, in which case [bodyPath]
  /// falls back to `superellipse`.
  final BlobPath? Function(Body)? draw;

  HiblobLayout({
    required this.shape,
    required this.body,
    required this.face,
    required this.eyes,
    required this.petals,
    required this.extra,
    required this.draw,
    this.bodyOffsetY = 0,
  });

  /// The core body's path — the shape's own hook when it names one,
  /// `superellipse` otherwise, exactly like the reference renderer's default.
  /// Traced against the body's *current* values every call.
  BlobPath bodyPath() {
    final BlobPath? traced = draw?.call(body);
    if (traced != null) return traced;
    return superellipse(Superellipse(
      cx: body.cx,
      cy: body.cy,
      rx: body.rx,
      ry: body.ry,
      n: body.n,
      rot: body.rot,
    ));
  }

  List<BlobPath> eyePaths() => [
        for (final Eye e in eyes)
          superellipse(Superellipse(
            cx: e.cx,
            cy: e.cy,
            rx: e.rx,
            ry: e.ry,
            n: e.n,
            rot: e.rot,
          )),
      ];
}

/// JS `Math.hypot(x, y)` — the naive form differs by at most an ULP, which the
/// reference-vector tolerance rules cover.
double _hypot2(double x, double y) => math.sqrt(x * x + y * y);

/// Fits the eye cluster against the silhouette's face region on both axes.
List<Eye> faceFit(Traits t, Body b, Ellipse face) {
  final double rx = b.rx;
  final double er0 = t.numIn('eye.rx', 0.075, 0.105) * rx;
  final double ratio = t.numIn('eye.ratio', 1.9, 3.2);
  final double scale = t.numIn('eye.scale', 0.78, 1.24);
  final double stretch = t.numIn('eye.stretch', 0.85, 1.18);
  final double clearance = t.numIn('eye.gap', 0.1, 0.24) * rx;
  final double wide = er0 * math.max(1, scale);
  final double tall = er0 * ratio * math.max(1, scale * stretch);
  final double gap0 = wide + rx * 0.03 + clearance;

  final double gx = t.jitter('gaze.x', 0.09) * face.rx;
  final double gy = t.numIn('gaze.y', -0.2, 0.08) * face.ry;
  final double dy = t.jitter('eye.dy', 0.04) * face.ry;
  final double reach = _hypot2(wide, tall);
  final double need = _hypot2(
    (gx.abs() + gap0 + reach) / face.rx,
    (gy.abs() + dy.abs() + reach) / face.ry,
  );
  final double fit = need > 0.9 ? 0.9 / need : 1;

  final double er = er0 * fit;
  final double eyeRy = er * ratio;
  final double gap = gap0 * fit;
  final double room = math.max(0, math.min(1, clearance / tall));
  final double bound = math.min(12, math.asin(room) * 180 / math.pi);
  final double lean = t.numIn('eye.lean', -1, 1) * bound;
  final double lean2 =
      math.max(-12.0, math.min(12.0, lean + t.jitter('eye.lean2', 3.5)));

  final double cx = face.cx + gx * fit;
  final double cy = face.cy + gy * fit;
  return [
    Eye(cx - gap, cy, er, eyeRy, t.numIn('eye.n', 3.5, 6), lean),
    Eye(
      cx + gap,
      cy + dy * fit,
      er * scale,
      eyeRy * scale * stretch,
      t.numIn('eye.n', 3.5, 6),
      lean2,
    ),
  ];
}

/// `[shape, upper edge of its band in [0, 1)]`, in order.
typedef Band = (Shape, double);

/// A composed style: the band table plus the eye fit.
class HiblobStyle {
  final List<Band> bands;
  final List<Eye> Function(Traits, Body, Ellipse) fit;

  /// Whether this style ships with a backdrop by default. Gen-2 does not: the
  /// body sits on whatever the host provides.
  final bool background;

  const HiblobStyle(this.bands, this.fit, {this.background = false});

  Shape _pick(double v) {
    for (final (Shape shape, double upTo) in bands) {
      if (v < upTo) return shape;
    }
    return bands.last.$1;
  }

  /// Resolves one seed's traits into the full layout.
  HiblobLayout layout(Traits t) {
    final Shape shape = _pick(t('shape'));
    final double r = t.numIn('body.r', 31, 38) * shape.core;
    final Body body = Body(
      cx: 50 + t.jitter('body.x', 1.5),
      cy: 50 + t.jitter('body.y', 1.5),
      rx: r,
      ry: r * t.numIn('body.ratio', 0.92, 1.08),
      n: t.numIn('body.n', 1.9, 2.5),
      rot: 0,
      radii: [
        for (var i = 0, len = t.intIn('body.pts', 6, 8); i < len; i++)
          1 + t.jitter('body.r$i', 0.16),
      ],
    );
    shape.body(t, body);

    // The body itself when the shape names no face, which is what a silhouette
    // convex around its own centre wants.
    final Ellipse face =
        shape.face(body) ?? Ellipse(body.cx, body.cy, body.rx, body.ry);
    final Deco deco = Deco();
    shape.decorate(t, body, deco);

    return HiblobLayout(
      shape: shape.name,
      body: body,
      face: face,
      eyes: fit(t, body, face),
      petals: deco.petals,
      extra: deco.extra,
      // The hook stays live, mirroring the TS renderer's `draw: shape.path`.
      draw: shape.path,
    );
  }
}
