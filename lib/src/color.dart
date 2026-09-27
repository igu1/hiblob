/// Palette construction.
///
/// The authored OKLCh palette pipeline.
///
/// Hue is the only value the seed controls. Lightness and chroma are authored
/// constants, which is what makes every hiblob look like it came from the
/// same designer rather than from a random number generator.
///
/// Colors are resolved to hex rather than emitted as `oklch()`. Doing the
/// conversion here also means the contrast guarantee is enforced against real
/// sRGB luminance instead of assumed from OKLab lightness, which drifts by up
/// to ~1.4:1 between hues at equal L.
library;

import 'dart:math' as math;

/// A color in OKLCh.
class Oklch {
  final double l;
  final double c;
  final double h;

  const Oklch(this.l, this.c, this.h);

  Oklch withL(double l) => Oklch(l, c, h);

  @override
  String toString() => 'Oklch($l, $c, $h)';
}

/// Every color slot a hiblob has.
const String colorBg = 'bg';
const String colorHead = 'head';
const String colorEye = 'eye';

/// The resolved palette, keyed by [colorBg] / [colorHead] / [colorEye].
typedef Palette = Map<String, String>;

/// JS `Math.round` — half toward positive infinity, not half away from zero.
double jsRound(double v) => (v + 0.5).floorToDouble();

/// `Math.cbrt`. dart:math has none; `pow(x, 1/3)` is accurate but may differ
/// from V8 by an ULP — the same engine-level difference the reference-vector
/// comparison rules already account for.
double cbrt(double x) =>
    x >= 0 ? math.pow(x, 1 / 3).toDouble() : -math.pow(-x, 1 / 3).toDouble();

/// `Math.hypot(x, y)` for two arguments. The naive form can differ from the
/// C library by an ULP; that difference is covered by the reference-vector
/// tolerance rules and never reaches the palette's quantized hex output.
double hypot2(double x, double y) => math.sqrt(x * x + y * y);

/// OKLCh -> linear-light sRGB. Components may fall outside [0,1] (out of
/// gamut).
(double, double, double) _toLinear(Oklch color) {
  final double r = color.h * math.pi / 180;
  final double a = color.c * math.cos(r);
  final double b = color.c * math.sin(r);

  final double l_ = color.l + 0.3963377774 * a + 0.2158037573 * b;
  final double m_ = color.l - 0.1055613458 * a - 0.0638541728 * b;
  final double s_ = color.l - 0.0894841775 * a - 1.291485548 * b;

  final double L = l_ * l_ * l_;
  final double M = m_ * m_ * m_;
  final double S = s_ * s_ * s_;

  return (
    4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S,
    -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S,
    -0.0041960863 * L - 0.7034186147 * M + 1.707614701 * S,
  );
}

bool _inGamut((double, double, double) rgb) =>
    rgb.$1 >= -1e-4 &&
    rgb.$1 <= 1 + 1e-4 &&
    rgb.$2 >= -1e-4 &&
    rgb.$2 <= 1 + 1e-4 &&
    rgb.$3 >= -1e-4 &&
    rgb.$3 <= 1 + 1e-4;

/// Resolves to in-gamut linear sRGB, reducing chroma if needed.
///
/// Chroma is the right axis to give up: lowering it desaturates, while
/// clipping channels shifts hue — a clipped vivid blue turns purple.
(double, double, double) _resolve(Oklch color) {
  var rgb = _toLinear(color);
  if (!_inGamut(rgb)) {
    double lo = 0;
    double hi = color.c;
    for (var i = 0; i < 12; i++) {
      final double mid = (lo + hi) / 2;
      if (_inGamut(_toLinear(Oklch(color.l, mid, color.h)))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    rgb = _toLinear(Oklch(color.l, lo, color.h));
  }
  return (
    rgb.$1.clamp(0.0, 1.0),
    rgb.$2.clamp(0.0, 1.0),
    rgb.$3.clamp(0.0, 1.0),
  );
}

/// WCAG relative luminance. The values coming out of [_resolve] are already
/// linear-light sRGB, which is exactly what WCAG's piecewise transfer function
/// produces — so this needs no further linearization.
double _luminance(Oklch color) {
  final rgb = _resolve(color);
  return 0.2126 * rgb.$1 + 0.7152 * rgb.$2 + 0.0722 * rgb.$3;
}

double contrast(Oklch a, Oklch b) {
  final double x = _luminance(a);
  final double y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Pushes `fg`'s lightness away from `bg` until the pair clears [min].
///
/// Walks in the direction it is already leaning first, so a dark ink on a
/// light head gets darker rather than flipping to light. If that direction
/// runs out of range, it tries the other way before giving up at pure black or
/// white.
Oklch ensureContrast(Oklch fg, Oklch bg, double min) {
  if (contrast(fg, bg) >= min) return fg;

  final double lean = fg.l >= bg.l ? 1 : -1;
  for (final double dir in [lean, -lean]) {
    double l = fg.l;
    for (var i = 0; i < 60; i++) {
      l = math.min(1.0, math.max(0.0, l + dir * 0.02));
      final Oklch probe = Oklch(l, fg.c, fg.h);
      if (contrast(probe, bg) >= min) return probe;
      if (l == 0 || l == 1) break;
    }
  }

  // Unreachable for the authored ramps, but a palette override could get here.
  final Oklch black = Oklch(0, 0, fg.h);
  final Oklch white = Oklch(1, 0, fg.h);
  return contrast(black, bg) >= contrast(white, bg) ? black : white;
}

String _hex2(int v) => v < 16 ? '0${v.toRadixString(16)}' : v.toRadixString(16);

String toHex(Oklch color) {
  final rgb = _resolve(color);
  final out = StringBuffer('#');
  for (final double v in [rgb.$1, rgb.$2, rgb.$3]) {
    final double s =
        v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
    out.write(_hex2(jsRound(s * 255).toInt()));
  }
  return out.toString();
}

/// sRGB hex -> OKLCh. The inverse of [_toLinear] plus [_resolve]'s decode, and
/// the only way back into the color space from a palette that has already been
/// serialized.
///
/// It exists because the tint has to start from the colors that are actually
/// on screen, not from the ramp that produced them: a palette override of
/// `head` or `eye` means a hot pair derived from the ramp instead would tint
/// toward a color the hiblob never wore.
Oklch fromHex(String hex) {
  final int n = int.parse(hex.substring(1), radix: 16);
  double decode(int v) {
    final double s = v / 255;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final double r = decode((n >> 16) & 255);
  final double g = decode((n >> 8) & 255);
  final double b = decode(n & 255);

  final double l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final double m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final double s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);

  final double a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  final double bb = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;

  return Oklch(
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    hypot2(a, bb),
    math.atan2(bb, a) * 180 / math.pi,
  );
}

/// Blend two colors in OKLab — `color-mix(in oklab, a, b t)`, done here.
///
/// Interpolating in OKLab means lerping cartesian `a`/`b`, not the polar
/// `c`/`h` this module otherwise speaks — a hue lerp would swing a
/// desaturated color around the wheel and pick up chroma that is in neither
/// endpoint.
Oklch mix(Oklch a, Oklch b, double t) {
  double rad(double v) => v * math.pi / 180;
  final double ax = a.c * math.cos(rad(a.h));
  final double ay = a.c * math.sin(rad(a.h));
  final double bx = b.c * math.cos(rad(b.h));
  final double by = b.c * math.sin(rad(b.h));
  final double x = ax + (bx - ax) * t;
  final double y = ay + (by - ay) * t;
  return Oklch(
    a.l + (b.l - a.l) * t,
    hypot2(x, y),
    math.atan2(y, x) * 180 / math.pi,
  );
}

/// [mix] between two serialized colors, serialized.
String mixHex(String a, String b, double t) =>
    toHex(mix(fromHex(a), fromHex(b), t));

/// The other blend, and it is deliberately not [mixHex].
///
/// [mixHex] is where a tinting pose *lands*: a tint picks a point on the OKLab
/// walk and the result is a finished endpoint. This is how a fill *travels*
/// between two finished colors while a pose morphs, and on the web that travel
/// is `transition: fill`, which CSS runs in sRGB. A substrate with no
/// transitions has to reproduce sRGB, not OKLab: the endpoints agree because
/// [mixHex] sets them; the path between them agrees because of this.
String fadeHex(String a, String b, double t) {
  final out = StringBuffer('#');
  for (var i = 1; i < 7; i += 2) {
    final int from = int.parse(a.substring(i, i + 2), radix: 16);
    final int to = int.parse(b.substring(i, i + 2), radix: 16);
    final int v = jsRound(from + (to - from) * t).toInt();
    out.write(_hex2(v));
  }
  return out.toString();
}

/// Where a tinting pose is heading.
///
/// Four numbers rather than an authored color, because the endpoint has to be
/// derived per seed. A [Tint] says *which way*, and the hiblob's own palette
/// says where that lands.
class Tint {
  /// Hue the body arrives at, in degrees. Reached outright, not approached.
  final double h;

  /// Lightness it heads toward.
  final double l;

  /// How far of the way to [l] the body actually travels, 0-1.
  final double pull;

  /// Chroma floor. The body never desaturates on the way.
  final double c;

  const Tint(this.h, this.l, this.pull, this.c);
}

/// Red, because every reference for anger is — and only 60% of the way there
/// in lightness, so the tone set survives the trip.
const Tint hot = Tint(27, 0.58, 0.6, 0.18);

/// The rest of the targets. `pull` is the dial that keeps them apart as much
/// as `h` is: [blush] travels only 0.4 of the way and lands pale — a shy
/// hiblob that goes as red as an angry one is an angry one.
const Tint rose = Tint(358, 0.72, 0.55, 0.16);
const Tint blush = Tint(12, 0.84, 0.4, 0.1);
const Tint bile = Tint(142, 0.66, 0.6, 0.13);

/// Every tint target the suite has to hold the contrast guarantee across.
const List<(String, Tint)> tints = [
  ('hot', hot),
  ('rose', rose),
  ('blush', blush),
  ('bile', bile),
];

/// A hair over the 4.5:1 the suite asserts. The margin is for 8-bit
/// quantization and nothing else.
const double _tintFloor = 4.55;

/// The palette a tinting pose heads toward, given the one it is tinting from.
///
/// Derived per seed rather than being a single authored color, and the reason
/// is polarity: hiblob flips its eye between near-black and near-white
/// depending on the body's lightness, and no fixed red clears 4.5:1 against
/// both.
///
/// The tinted body meets its target **partway** rather than landing on it, so
/// a pale hiblob stays recognisably pale and an ink one recognisably dark
/// while both have somewhere to go. The eye endpoint is then pushed until
/// **every point along the mix** clears the floor, not merely both ends.
(String, String) tinted(String head, String eye, Tint t) {
  final Oklch base = fromHex(head);
  final Oklch baseEye = fromHex(eye);

  // Chroma is floored rather than replaced: a body that is already vivid
  // should not *lose* saturation on the way.
  Oklch hotHead = Oklch(
    base.l + (t.l - base.l) * t.pull,
    math.max(base.c, t.c),
    t.h,
  );
  // The body still has to be visible on a dark page at full heat, which is the
  // same floor the ramp enforces and for the same reason.
  hotHead = ensureContrast(hotHead, darkSurface, surfaceFloor);

  Oklch hotEye = ensureContrast(baseEye, hotHead, _tintFloor);

  // Walked rather than assumed, in the exact terms that ship — the hexes,
  // mixed the way [mixHex] mixes them — because "both ends pass" does not
  // imply "every point passes". Eleven samples catch that wobble; the loop
  // normally exits on the first pass and pushes the eye endpoint further from
  // the body when it does not.
  final double dir = hotEye.l >= hotHead.l ? 1 : -1;
  final String headHex = toHex(hotHead);
  for (var pass = 0; pass < 40; pass++) {
    final String eyeHex = toHex(hotEye);
    double worst = double.infinity;
    for (var i = 0; i <= 10; i++) {
      final double tt = i / 10;
      worst = math.min(
        worst,
        contrast(
          fromHex(mixHex(eye, eyeHex, tt)),
          fromHex(mixHex(head, headHex, tt)),
        ),
      );
    }
    if (worst >= _tintFloor) return (headHex, eyeHex);
    final double l = math.min(1.0, math.max(0.0, hotEye.l + dir * 0.02));
    if (l == hotEye.l) return (headHex, eyeHex);
    hotEye = hotEye.withL(l);
  }

  return (headHex, toHex(hotEye));
}

/// A lightness/chroma swatch and the upper edge of the band that selects it.
class _Tone {
  final double edge;
  final double l;
  final double c;
  const _Tone(this.edge, this.l, this.c);
}

const List<_Tone> _tones = [
  // Thresholds are cumulative, so pale and mid tones dominate and the
  // near-black body stays a rare find.
  _Tone(0.2, 0.86, 0.085), // pastel
  _Tone(0.36, 0.9, 0.028), // pale neutral
  _Tone(0.62, 0.73, 0.135), // mid
  _Tone(0.8, 0.62, 0.165), // deep
  _Tone(0.93, 0.87, 0.16), // bright
  // Dark, but not darker than a dark host surface. At l 0.17 this swatch
  // scored 1.03:1 against a near-black page and the body simply vanished,
  // leaving two floating eyes. l 0.34 still reads as the ink tone and clears
  // both ends.
  _Tone(1.0, 0.34, 0.035), // ink
];

_Tone _toneAt(double v) =>
    _tones.firstWhere((t) => v < t.edge, orElse: () => _tones.first);

/// The darkest host surface a backdrop-less blob is expected to land on, and
/// the ratio it must clear against it.
///
/// The floor can only relate colors that are in the palette, and the surface
/// never is: hiblob ships with its backdrop off, so the body sits directly
/// on whatever the page provides.
const Oklch darkSurface = Oklch(0.145, 0, 0); // ~= #0a0a0b
const double surfaceFloor = 1.5;

Map<String, Oklch> _ramp(double hue, double tone) {
  final _Tone t = _toneAt(tone);
  final Oklch head =
      ensureContrast(Oklch(t.l, t.c, hue), darkSurface, surfaceFloor);
  return {
    colorBg: Oklch(0.965, 0.01, hue),
    colorHead: head,
    // Polarity follows the body: dark eyes on a light body, light eyes on a
    // dark one. Without this the ink tone would render an invisible face.
    colorEye: head.l >= 0.5 ? Oklch(0.17, 0.02, hue) : Oklch(0.97, 0.012, hue),
  };
}

/// Minimum contrast ratios as (foreground, background, ratio), applied in
/// order. Later pairs resolve against already-final earlier colors, so the
/// chain converges. `4.5` on the eyes is the WCAG text floor: they are small
/// marks that have to read at 24px.
///
/// The body/backdrop floor is deliberately weak. The backdrop is off by
/// default, and the pale swatches are meant to sit quietly on a light surface.
const List<(String, String, double)> floors = [
  (colorHead, colorBg, 1.25),
  (colorEye, colorHead, 4.5),
];

/// The palette in OKLCh, before hex encoding.
Map<String, Oklch> ramp(double hue, [bool enforce = true, double tone = 0]) {
  final Map<String, Oklch> r = _ramp(hue, tone);
  if (enforce) {
    for (final (String fg, String bg, double min) in floors) {
      r[fg] = ensureContrast(r[fg]!, r[bg]!, min);
    }
  }
  return r;
}

/// The authored ramp: the seed picks a hue and a tone, and everything follows.
Palette palette(double hue, [bool enforce = true, double tone = 0]) {
  final Map<String, Oklch> r = ramp(hue, enforce, tone);
  return {
    for (final MapEntry<String, Oklch> entry in r.entries)
      entry.key: toHex(entry.value),
  };
}
