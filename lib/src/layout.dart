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
  });
}

/// Resolves [name] with [options] into drawable geometry and palette.
ResolvedHiblob resolve(String name,
    {HiblobOptions options = const HiblobOptions()}) {
  final traits = traitsFor(name, options: options);
  final seed = options.normalize ? name.trim().toLowerCase() : name;
  final shape = bandFor(traits['shape']!, shapeBands);
  final toneBand = bandFor(traits['tone']!, toneBands);
  final hue = traits['hue']! * 360;

  final (backdrop, backdropColor) = _backdrop(options, hue, toneBand);
  final body = _body(shape, traits);
  final (eyes, eyeColor, headColor) =
      _face(shape, traits, options, hue, toneBand);

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
      return left
          ? ([ellipse(x, y, rx * 0.95, ry * 0.95)], false)
          : (
              [
                polyline([(x: x - rx * 0.85, y: y), (x: x + rx * 0.85, y: y)])
              ],
              true
            );
    default: // idle
      return ([ellipse(x, y, rx, ry)], false);
  }
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
    head = blendArgb(head, tint, options.expression.tintAlpha);
  }

  final headPin = options.palette[PaletteKeys.head];
  if (headPin != null) head = hexToArgb(headPin);
  final eyePin = options.palette[PaletteKeys.eye];
  if (eyePin != null) eye = hexToArgb(eyePin);
  return (head, eye);
}
