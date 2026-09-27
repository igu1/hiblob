/// The layout: traits → geometry, eyes, and palette for one hiblob.
///
/// This file owns the frozen seed-to-look contract. The silhouette band
/// table, every numeric range read from a trait, the tone set, and the eye
/// placement rules move together — changing any of them changes which figure
/// a name resolves to.
library;

import 'dart:math' as math;

import 'color.dart';
import 'expressions.dart';
import 'geometry.dart';
import 'hash.dart';
import 'options.dart';
import 'traits.dart';

/// The view box is square; every coordinate below lives inside it.
const double viewBoxSize = 100.0;

/// One eye: the marks that draw it (filled or stroked), and its center, used
/// to scale the eye around itself when it blinks.
class EyeGroup {
  final List<GeometryPath> marks;

  /// Whether every mark in [marks] is a stroked line. Closed-line eyes are
  /// already "shut", so motion skips blinking them.
  final bool strokeOnly;
  final double cx;
  final double cy;

  const EyeGroup(this.marks,
      {required this.strokeOnly, required this.cx, required this.cy});
}

/// One accessory mark and the color it is painted with.
class Accessory {
  final GeometryPath path;

  /// Optional clipping outline for fitted cap details.
  final GeometryPath? clip;

  /// ARGB color.
  final int color;

  /// Whether the accessory is painted below the eyes (for example blush
  /// discs) or above them (for example glasses frames).
  final bool underEyes;

  const Accessory(this.path,
      {required this.color, this.underEyes = false, this.clip});
}

/// A fully resolved, ready-to-draw hiblob.
class ResolvedHiblob {
  final String name;
  final String seed;
  final HiblobOptions options;
  final Map<String, double> traits;

  /// Which silhouette the shape trait picked.
  final String shape;

  /// The resolved hue in degrees — pinned when [HiblobOptions.hue] is set.
  final double hue;

  /// Which tone band the tone trait picked.
  final String toneBand;

  /// The backdrop plate, or `null` for [Backdrop.none].
  final GeometryPath? backdrop;
  final int backdropColor;

  /// The body: the main silhouette first, then any extra volumes (nubs,
  /// puffs), all painted [headColor].
  final List<GeometryPath> body;
  final int headColor;

  /// Two eye groups — left, then right.
  final List<EyeGroup> eyes;
  final int eyeColor;

  /// The mouth path, or `null` when [HiblobOptions.mouth] is off or the
  /// expression draws none.
  final GeometryPath? mouth;

  /// Deterministic accessories, in paint order.
  final List<Accessory> accessories;

  const ResolvedHiblob({
    required this.name,
    required this.seed,
    required this.options,
    required this.traits,
    required this.shape,
    required this.hue,
    required this.toneBand,
    required this.backdrop,
    required this.backdropColor,
    required this.body,
    required this.headColor,
    required this.eyes,
    required this.eyeColor,
    this.mouth,
    this.accessories = const [],
  });
}

/// One drawing step: a path and the ARGB color it is painted with.
class DrawStep {
  final GeometryPath path;

  /// Optional clipping outline applied before drawing this step.
  final GeometryPath? clip;

  /// ARGB color. For stroked paths this is the stroke color.
  final int color;

  const DrawStep(this.path, this.color, {this.clip});
}

/// The completed draw list for [name]: every path in paint order (backdrop,
/// body, mouth, and accessories), each with its color. Stroked paths carry
/// their stroke color; the caller chooses stroke vs fill from
/// [GeometryPath.stroke].
List<DrawStep> layoutFor(String name,
    {HiblobOptions options = const HiblobOptions()}) {
  final resolved = resolve(name, options: options);
  return drawStepsOf(resolved);
}

/// The body silhouette and any extra volumes ([ResolvedHiblob.body]) for
/// [name], without palette information.
List<GeometryPath> partsFor(String name,
        {HiblobOptions options = const HiblobOptions()}) =>
    resolve(name, options: options).body;

/// Flattens [resolved] into a paint-order draw list — what [layoutFor]
/// returns for a name, here applied to an already resolved figure.
List<DrawStep> drawStepsOf(ResolvedHiblob resolved) {
  final steps = <DrawStep>[];
  final backdrop = resolved.backdrop;
  if (backdrop != null) {
    steps.add(DrawStep(backdrop, resolved.backdropColor));
  }
  steps.addAll(
    [for (final part in resolved.body) DrawStep(part, resolved.headColor)],
  );
  final mouth = resolved.mouth;
  if (mouth != null) {
    steps.add(DrawStep(mouth, resolved.eyeColor));
  }
  for (final accessory in resolved.accessories.where((a) => a.underEyes)) {
    steps.add(DrawStep(accessory.path, accessory.color, clip: accessory.clip));
  }
  for (final eye in resolved.eyes) {
    steps.addAll(
        [for (final mark in eye.marks) DrawStep(mark, resolved.eyeColor)]);
  }
  for (final accessory in resolved.accessories.where((a) => !a.underEyes)) {
    steps.add(DrawStep(accessory.path, accessory.color, clip: accessory.clip));
  }
  return steps;
}

/// Resolves [name] with [options] into drawable geometry and palette.
ResolvedHiblob resolve(String name,
    {HiblobOptions options = const HiblobOptions()}) {
  final traits = traitsFor(name, options: options);
  final seed = options.normalize ? normalizeSeed(name) : name;
  final shape = bandFor(traits['shape']!, shapeBands);
  final toneBand = bandFor(traits['tone']!, toneBands);
  final hue = traits['hue']! * 360;

  final (backdrop, backdropColor) = _backdrop(options, hue, toneBand);
  final body = _body(shape, traits);
  final (eyes, eyeColor, headColor) =
      _face(shape, traits, options, hue, toneBand);
  final mouth =
      options.mouth ? _mouth(shape, traits, options.expression, eyes) : null;
  final accessories =
      _accessories(shape, name, options, traits, eyes, headColor, eyeColor);

  return ResolvedHiblob(
    name: name,
    seed: seed,
    options: options,
    traits: traits,
    shape: shape,
    hue: hue,
    toneBand: toneBand,
    backdrop: backdrop,
    backdropColor: backdropColor,
    body: body,
    headColor: headColor,
    eyes: eyes,
    eyeColor: eyeColor,
    mouth: mouth,
    accessories: accessories,
  );
}

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

({double s, double l}) _toneBase(String toneBand) => switch (toneBand) {
      'pale' => (s: 0.42, l: 0.88),
      'soft' => (s: 0.55, l: 0.78),
      'mid' => (s: 0.60, l: 0.66),
      'deep' => (s: 0.55, l: 0.50),
      _ => (s: 0.30, l: 0.24), // ink
    };

(GeometryPath?, int) _backdrop(
    HiblobOptions options, double hue, String toneBand) {
  if (options.background == Backdrop.none) return (null, 0);
  final color = options.palette[PaletteKeys.bg] != null
      ? hexToArgb(options.palette[PaletteKeys.bg]!)
      : hslToArgb(hue, 0.55, toneBand == 'pale' ? 0.95 : 0.93);
  final path = switch (options.background) {
    Backdrop.squircle => superellipse(50, 50, 48, 48, 4),
    Backdrop.circle => circle(50, 50, 48),
    Backdrop.square => roundedRect(50, 50, 96, 96, 6),
    Backdrop.none => null,
  };
  return (path, color);
}

// ---------------------------------------------------------------------------
// Body silhouettes
// ---------------------------------------------------------------------------

double _bodyR(Map<String, double> t) => 26.0 + t['body.r']! * 8.0;

List<GeometryPath> _body(String shape, Map<String, double> t) {
  final cx = 50.0, cy = 52.0;
  final r = _bodyR(t);
  switch (shape) {
    case 'round':
      return [circle(cx, cy, r)];
    case 'organic':
      final a = t['detail.a']!, b = t['detail.b']!, c = t['detail.c']!;
      final p = t['detail.phase']! * 2 * math.pi;
      final waves = [
        RadialWave(3, 0.020 + 0.050 * a, p),
        RadialWave(5, 0.012 + 0.045 * b, p * 2.7 + 1.3),
        RadialWave(7, 0.008 + 0.028 * c, p * 4.1 + 2.9),
      ];
      return [radialBlob(cx, cy, r * 1.02, waves)];
    case 'boxy':
      return [superellipse(cx, cy, r * 1.06, r * 1.06, 3.4)];
    case 'nub':
      final angle = -math.pi / 2 + (t['nub.angle']! - 0.5) * 2.4;
      final d = r * 0.82;
      final nubR = r * 0.34;
      return [
        circle(cx, cy, r * 0.94),
        circle(cx + d * math.cos(angle), cy + d * math.sin(angle), nubR),
      ];
    case 'capsule':
      final vertical = t['body.aspect']! < 0.5;
      final w = vertical ? r * 1.60 : r * 2.24;
      final h = vertical ? r * 2.24 : r * 1.60;
      return [roundedRect(cx, cy, w, h, math.min(w, h) / 2)];
    case 'hexagon':
      return [roundedPolygon(cx, cy, r * 1.06, 6, 0.18, rotation: math.pi / 6)];
    case 'triangle':
      return [
        roundedPolygon(cx, cy, r * 1.18, 3, 0.20, rotation: -math.pi / 2)
      ];
    case 'droplet':
      final bulbR = r * 0.86;
      return [droplet(cx, cy + r * 0.16, bulbR, bulbR * 0.72)];
    case 'cloud':
      return [
        circle(cx, cy + r * 0.18, r * 0.82),
        circle(cx - r * 0.62, cy + r * 0.05, r * 0.42),
        circle(cx + r * 0.62, cy + r * 0.08, r * 0.40),
        circle(cx, cy - r * 0.32, r * 0.48),
      ];
    case 'sun':
      return [star(cx, cy, r * 1.16, r * 0.74, 8, rotation: math.pi / 8)];
    case 'gem':
      return [
        roundedPolygon(cx, cy, r * 1.10, 5, 0.12, rotation: -math.pi / 2)
      ];
    case 'pillow':
      return [superellipse(cx, cy, r * 1.10, r * 0.92, 2.2)];
  }
  throw StateError('unknown shape $shape');
}

/// Conservative horizontal half-extent of the body at the eye line, used to
/// keep eyes inside the silhouette.
double _halfWidthAtFace(String shape, Map<String, double> t) {
  final r = _bodyR(t);
  return switch (shape) {
    'round' => r,
    'organic' => r * 1.02 * 1.10, // widest radial wobble
    'boxy' => r * 1.06,
    'nub' => r * 0.94,
    'capsule' => t['body.aspect']! < 0.5 ? r * 0.80 : r * 1.12,
    'hexagon' => r * 0.98,
    'triangle' => r * 0.90,
    'droplet' => r * 0.86 * 0.95,
    'cloud' => r * 0.82,
    'sun' => r * 0.74,
    'gem' => r * 0.95,
    'pillow' => r * 1.10,
    _ => throw StateError('unknown shape $shape'),
  };
}

double _faceDy(String shape, Map<String, double> t) {
  final r = _bodyR(t);
  return switch (shape) {
    'round' => 0.0,
    'organic' => 0.0,
    'boxy' => -1.5,
    'nub' => 0.5,
    'capsule' => 0.0,
    'hexagon' => -1.0,
    'triangle' => 2.5,
    'droplet' => r * 0.16 + 1.5, // inside the bulb
    'cloud' => 0.5,
    'sun' => 0.0,
    'gem' => 1.0,
    'pillow' => -1.0,
    _ => throw StateError('unknown shape $shape'),
  };
}

// ---------------------------------------------------------------------------
// Face
// ---------------------------------------------------------------------------

(List<EyeGroup>, int, int) _face(
  String shape,
  Map<String, double> t,
  HiblobOptions options,
  double hue,
  String toneBand,
) {
  final cx = 50.0, cy = 52.0;
  final r = _bodyR(t);

  // Palette first: eyes need the head color for the contrast floor.
  final (headColor, eyeColor) = _palette(t, options, hue, toneBand);

  final expression = options.expression;
  final rx = 3.1 - 1.0 * t['eye.ratio']!;
  final ry = math.min(rx * (1 + 2.4 * t['eye.ratio']!), 9.5);
  final fy = cy + t['face.offset']! * 2.0 + _faceDy(shape, t);
  final eyeY = (fy + t['eye.offset']! * 2.2 + expression.eyeOffsetDy)
      .clamp(cy - r * 0.42, cy + r * 0.38);
  var spread = 5.2 + 4.6 * t['eye.spacing']!;
  spread = math.max(
    spread,
    rx * 2.6, // eyes never fuse
  );
  // Keep the whole eye, plus a margin, inside the silhouette's half width.
  spread = math.min(spread, (_halfWidthAtFace(shape, t) - rx - 1.5) * 0.90);

  EyeGroup buildEye(bool left) {
    final sign = left ? -1.0 : 1.0;
    final x = cx + sign * spread + expression.eyeOffsetDx;
    final y = eyeY;
    final (marks, strokeOnly) = _eyeMarks(expression, left, x, y, rx, ry);
    return EyeGroup(marks, strokeOnly: strokeOnly, cx: x, cy: y);
  }

  return ([buildEye(true), buildEye(false)], eyeColor, headColor);
}

(List<GeometryPath>, bool) _eyeMarks(
  Expression expression,
  bool left,
  double x,
  double y,
  double rx,
  double ry,
) {
  switch (expression.id) {
    case 'happy':
      return ([halfDisc(x, y + ry * 0.15, rx * 1.15, down: true)], false);
    case 'sad':
      return ([halfDisc(x, y + ry * 0.2, rx * 1.05, down: false)], false);
    case 'mad':
      {
        final hw = rx * 1.15, hh = ry * 0.55;
        final angle = (left ? 1.0 : -1.0) * 0.24;
        Pt rot(double dx, double dy) => rotatePt(x + dx, y + dy, x, y, angle);
        return (
          [
            quad(rot(-hw, -hh), rot(hw, -hh), rot(hw, hh), rot(-hw, hh)),
          ],
          false,
        );
      }
    case 'surprised':
      return ([ellipse(x, y, rx * 1.20, rx * 1.30)], false);
    case 'wink':
      return left
          ? ([ellipse(x, y, rx, ry)], false)
          : (
              [
                polyline([(x: x - rx * 0.9, y: y), (x: x + rx * 0.9, y: y)])
              ],
              true
            );
    case 'sleepy':
      return ([halfDisc(x, y, rx * 1.10, down: true)], false);
    case 'smug':
      return left
          ? ([ellipse(x, y, rx * 0.95, ry)], false)
          : (
              [
                polyline([
                  (x: x - rx * 0.8, y: y + 0.7),
                  (x: x + rx * 0.9, y: y - 1.0),
                ])
              ],
              true
            );
    case 'unsure':
      return (
        [
          left
              ? ellipse(x, y, rx, ry)
              : ellipse(x, y + 0.8, rx * 0.65, ry * 0.65)
        ],
        false,
      );
    case 'scared':
      return ([ellipse(x, y, rx * 1.30, ry * 1.15)], false);
    case 'love':
      {
        final r = rx * 0.62;
        return (
          [
            circle(x - rx * 0.55, y - ry * 0.18, r),
            circle(x + rx * 0.55, y - ry * 0.18, r),
            quad(
              (x: x, y: y + ry * 0.80),
              (x: x - rx * 1.02, y: y - ry * 0.32),
              (x: x + rx * 1.02, y: y - ry * 0.32),
              (x: x, y: y + ry * 0.80),
            ),
          ],
          false,
        );
      }
    case 'shy':
      return ([halfDisc(x, y, rx * 0.95, down: true)], false);
    case 'sick':
      {
        final dx = rx * 0.85;
        final dy = (left ? 1.0 : -1.0) * 0.7;
        return (
          [
            polyline([(x: x - dx, y: y + dy), (x: x + dx, y: y - dy * 0.7)])
          ],
          true,
        );
      }
    case 'thinking':
      {
        // Seesaw loop: a slow horizontal sway, driven below.
        return left
            ? ([ellipse(x, y, rx * 0.95, ry * 0.95)], false)
            : (
                [
                  polyline([(x: x - rx * 0.85, y: y), (x: x + rx * 0.85, y: y)])
                ],
                true
              );
      }
    case 'grin':
      return ([ellipse(x, y, rx * 1.05, ry)], false);
    case 'frown':
      return ([ellipse(x, y, rx, ry * 0.9)], false);
    default: // idle
      return ([ellipse(x, y, rx, ry)], false);
  }
}

/// The mouth for [expression], centered under the eye line. `null` when the
/// expression draws no mouth (all currently do when enabled).
GeometryPath? _mouth(
  String shape,
  Map<String, double> t,
  Expression expression,
  List<EyeGroup> eyes,
) {
  final cx = 50.0;
  final mouthTrait = t['mouth']!;
  final eyeCy = (eyes[0].cy + eyes[1].cy) / 2;
  final y = math
      .min(eyeCy + 4.6 + 1.8 * mouthTrait, 50 + _bodyR(t) * 0.55)
      .clamp(0.0, 100.0);
  final x = cx + expression.eyeOffsetDx * 0.25;
  // Width grows with the mouth trait but stays well inside the silhouette.
  final half = math.min(
    2.5 + 3.6 * mouthTrait,
    _halfWidthAtFace(shape, t) * 0.72,
  );
  final depth = 2.2 + 3.0 * mouthTrait;

  switch (expression.id) {
    case 'happy':
      return _smile(x, y, half, depth * 0.9);
    case 'grin':
      return _smile(x, y, half * 1.15, depth * 1.25);
    case 'sad':
      return _smile(x, y, half * 0.9, -depth * 0.7);
    case 'frown':
      return _smile(x, y, half, -depth);
    case 'surprised':
      return ellipse(x, y + 0.5, half * 0.55, half * 0.62);
    case 'scared':
      return ellipse(x, y + 0.5, half * 0.62, half * 0.75);
    case 'sleepy':
      return ellipse(x, y + 0.6, half * 0.45, half * 0.5);
    case 'love':
      return _smile(x, y, half * 1.05, depth * 0.8);
    case 'shy':
      return polyline(
        [(x: x - half * 0.6, y: y + 0.9), (x: x + half * 0.6, y: y - 0.2)],
        width: 1.5,
      );
    case 'unsure':
      return polyline(
        [(x: x - half * 0.62, y: y + 0.5), (x: x + half * 0.62, y: y + 0.9)],
        width: 1.6,
      );
    case 'sick':
      return polyline(
        [
          (x: x - half, y: y),
          (x: x - half * 0.5, y: y - 1.2),
          (x: x, y: y + 0.6),
          (x: x + half * 0.5, y: y - 1.2),
          (x: x + half, y: y),
        ],
        width: 1.5,
      );
    case 'smug':
      return polyline(
        [(x: x - half * 0.7, y: y - 0.5), (x: x + half * 0.75, y: y + 1.2)],
        width: 1.6,
      );
    case 'mad':
      return polyline(
        [(x: x - half * 0.7, y: y + 1.1), (x: x + half * 0.7, y: y - 0.9)],
        width: 1.6,
      );
    case 'thinking':
      return polyline(
        [
          (x: x - half * 0.55 + expression.eyeOffsetDx * 0.2, y: y - 0.6),
          (x: x + half * 0.55 + expression.eyeOffsetDx * 0.2, y: y - 1.0),
        ],
        width: 1.5,
      );
    default: // idle — a gentle, small smile
      return _smile(x, y, half * 0.85, depth * 0.5);
  }
}

/// A filled lens-shaped mouth that opens downward for positive [depth] and
/// upward (a frown) for negative depth.
GeometryPath _smile(double x, double y, double half, double depth) {
  return GeometryPath([
    MoveTo(x - half, y),
    CubicTo(
      x - half * 0.35,
      y + depth,
      x + half * 0.35,
      y + depth,
      x + half,
      y,
    ),
    const ClosePath(),
  ]);
}

/// The accessory layout: pin/read presence per key, then build marks.
List<Accessory> _accessories(
  String shape,
  String name,
  HiblobOptions options,
  Map<String, double> t,
  List<EyeGroup> eyes,
  int headColor,
  int eyeColor,
) {
  final seed = options.normalize ? normalizeSeed(name) : name;
  final present = <String, bool>{
    for (final key in AccessoryKeys.all)
      key: _pinOrHash(options, key, stream(seed, 'accessory.$key')),
  };
  final r = _bodyR(t);
  final cx = 50.0, cy = 52.0;
  final accent = eyeColor;
  final fringe = relativeLuminance(headColor) > 0.30
      ? oklchBlend(headColor, 0xFF20242E, 0.55)
      : oklchBlend(headColor, 0xFFF2F2F2, 0.35);
  final blush = oklchBlend(headColor, 0xFFF4A9BE, 0.65);
  final result = <Accessory>[];

  final glasses = present[AccessoryKeys.glasses]!;
  if (glasses && eyes.length == 2) {
    final lensWidth = math.min(10.8, eyes[1].cx - eyes[0].cx - 2.4);
    final rr = lensWidth / 2;
    final ey = (eyes[0].cy + eyes[1].cy) / 2;
    final lensHeight = math.max(
        11.0, 2 * (3.1 - t['eye.ratio']!) * (1 + 2.4 * t['eye.ratio']!) + 3);
    // Round, slightly taller-than-wide lenses with a full-radius top.
    for (final eye in eyes) {
      final lens =
          roundedRect(eye.cx, ey, lensWidth, lensHeight, lensHeight / 2 + 0.6);
      result.add(Accessory(
        GeometryPath(lens.commands, stroke: true, strokeWidth: 1.8),
        color: accent,
      ));
    }
    // Curved bridge.
    result.add(Accessory(
      GeometryPath([
        MoveTo(eyes[0].cx + rr, ey - 1.4),
        QuadraticTo(
            (eyes[0].cx + eyes[1].cx) / 2, ey - 4.4, eyes[1].cx - rr, ey - 1.4),
      ], stroke: true, strokeWidth: 1.8),
      color: accent,
    ));
    // Temple arms run from the lens edge to the silhouette, clipped to the
    // body so they always finish on the outline whatever the shape.
    final bodies = _body(shape, t);
    for (final side in [-1.0, 1.0]) {
      final eye = side < 0 ? eyes[0] : eyes[1];
      final armX = eye.cx + side * (rr + 2.0);
      result.add(Accessory(
        GeometryPath([
          MoveTo(eye.cx + side * (rr - 0.4), ey - 1.0),
          QuadraticTo(armX, ey - 2.6, eye.cx + side * (rr + 5.0), ey - 2.6),
        ], stroke: true, strokeWidth: 1.5),
        color: accent,
        clip: bodies.first,
      ));
    }
  }

  final fringeOn = present[AccessoryKeys.fringe]!;
  if (fringeOn) {
    // Cover the upper portion of every body volume, including nubs and
    // cloud puffs. A generic circular dome cannot fit these silhouettes.
    final edgeY = cy - r * 0.38;
    final crownClip = roundedRect(50, edgeY / 2, 100, edgeY, 0);
    final bandClip = roundedRect(50, edgeY - 1.8, 100, 3.6, 0);
    final bodies = _body(shape, t);
    for (final part in bodies) {
      result.add(Accessory(part, color: fringe, clip: crownClip));
    }
    for (final part in bodies) {
      result.add(Accessory(part,
          color: oklchBlend(fringe, accent, 0.3), clip: bandClip));
    }
    // Subtle panel stitching stays inside the silhouette.
    for (final part in bodies) {
      for (final side in [-1.0, 1.0]) {
        result.add(Accessory(
            GeometryPath([
              MoveTo(cx + side * 3, cy - r * 0.78),
              QuadraticTo(
                  cx + side * 6, cy - r * 0.65, cx + side * 7, edgeY - 4.5),
            ], stroke: true, strokeWidth: 0.7),
            color: oklchBlend(fringe, headColor, 0.28),
            clip: part));
      }
    }
  }

  final blushOn = present[AccessoryKeys.blush]!;
  if (blushOn && eyes.length == 2) {
    final ey = eyes[0].cy;
    final eyeSpread = (eyes[1].cx - eyes[0].cx).abs();
    final dx = math.max(eyeSpread, 8.0) / 2 + 2.2;
    for (final side in [-1.0, 1.0]) {
      result.add(Accessory(
        circle(cx + side * dx, ey + 3.2, math.max(eyeSpread * 0.30, 2.6)),
        color: blush,
        underEyes: true,
      ));
    }
  }

  final antennae = present[AccessoryKeys.antennae]!;
  if (antennae) {
    final tipY = cy - r - 4.5;
    for (final side in [-1.0, 1.0]) {
      final tipX = cx + side * 3.4 + (side > 0 ? 2.0 : -2.0);
      result.add(Accessory(
        polyline([(x: cx + side * 2.2, y: cy - r * 0.95), (x: tipX, y: tipY)],
            width: 1.3),
        color: accent,
      ));
      result.add(Accessory(circle(tipX, tipY, 1.6), color: accent));
    }
  }
  return result;
}

bool _pinOrHash(HiblobOptions options, String key, double hash) {
  final pin = options.accessories[key];
  if (pin != null) return pin >= 0.5;
  final prob = AccessoryKeys.defaultProbabilities[key] ?? 0.0;
  return hash < prob;
}

(int, int) _palette(
  Map<String, double> t,
  HiblobOptions options,
  double hue,
  String toneBand,
) {
  final (:s, :l) = _toneBase(toneBand);
  final sJ = (s + (t['detail.b']! - 0.5) * 0.10).clamp(0.05, 0.95);
  final lJ = (l + (t['detail.c']! - 0.5) * 0.08).clamp(0.05, 0.95);
  var head = hslToArgb(hue, sJ, lJ);
  var eye = relativeLuminance(head) > 0.30
      ? hslToArgb(hue, 0.45, 0.13)
      : hslToArgb(hue, 0.30, 0.96);

  if (options.contrast) {
    final lh = relativeLuminance(head);
    var le = relativeLuminance(eye);
    if ((lh - le).abs() < 0.32) {
      eye = lh > 0.30 ? hslToArgb(hue, 0.45, 0.06) : hslToArgb(hue, 0.30, 0.99);
      le = relativeLuminance(eye);
      if ((lh - le).abs() < 0.32) {
        head = lh > 0.30
            ? hslToArgb(hue, sJ, math.min(lJ + 0.10, 0.95))
            : hslToArgb(hue, sJ, math.max(lJ - 0.10, 0.05));
      }
    }
  }

  final tint = tintFor(options.expression);
  if (tint != 0x00000000 && options.expression.tintAlpha > 0) {
    head = oklchBlend(head, tint, options.expression.tintAlpha);
  }

  final headPin = options.palette[PaletteKeys.head];
  if (headPin != null) head = hexToArgb(headPin);
  final eyePin = options.palette[PaletteKeys.eye];
  if (eyePin != null) eye = hexToArgb(eyePin);
  return (head, eye);
}
