/// Color math for the hiblob palette.
///
/// Colors are authored in HSL, carried as 32-bit ARGB ints, compared with the
/// WCAG relative-luminance formula when the contrast floor is on, and blended
/// for expression tints. The OKLCh helpers expose the same colors in a
/// perceptually uniform space: `argbToOklch` reads a color's lightness,
/// chroma, and hue, `oklchToArgb` converts back, and [oklchBlend] mixes two
/// colors the way the eye sees them instead of along sRGB byte ramps. No
/// `dart:ui` — the Flutter layer converts.
library;

import 'dart:math' as math;

/// Converts HSL components to an opaque 32-bit ARGB value.
///
/// [h] is in degrees (any real number; it wraps), [s] and [l] are clamped to
/// `[0, 1]`.
int hslToArgb(double h, double s, double l) {
  h = ((h % 360) + 360) % 360;
  s = s.clamp(0.0, 1.0);
  l = l.clamp(0.0, 1.0);
  final c = (1 - (2 * l - 1).abs()) * s;
  final hp = h / 60;
  final x = c * (1 - ((hp % 2) - 1).abs());
  double r = 0, g = 0, b = 0;
  if (hp < 1) {
    r = c;
    g = x;
  } else if (hp < 2) {
    r = x;
    g = c;
  } else if (hp < 3) {
    g = c;
    b = x;
  } else if (hp < 4) {
    g = x;
    b = c;
  } else if (hp < 5) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  final m = l - c / 2;
  int toByte(double v) => ((v + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | (toByte(r) << 16) | (toByte(g) << 8) | toByte(b);
}

/// The tuple of a color's OMachLCh coordinates.
/// (L in `[0,1]`, C in `[0,~0.4]`, H in degrees `[0,360)`.)
typedef Oklch = ({double l, double c, double h});

/// Converts an ARGB color to OKLCh.
///
/// The route is the standard one: sRGB → linear sRGB → OKLab → OKLCh.
Oklch argbToOklch(int argb) {
  final l0 = ((argb >> 16) & 0xFF) / 255.0;
  final l1 = ((argb >> 8) & 0xFF) / 255.0;
  final l2 = (argb & 0xFF) / 255.0;
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(l0), g = lin(l1), b = lin(l2);

  const l_ = [0.4122214705, 0.5363325363, 0.0514459929];
  const m_ = [0.2119034982, 0.6806995451, 0.1073969566];
  const s_ = [0.0883024619, 0.2817188376, 0.6299787005];
  final l = (l_[0] * r + l_[1] * g + l_[2] * b).pow(1.0 / 3.0);
  final m = (m_[0] * r + m_[1] * g + m_[2] * b).pow(1.0 / 3.0);
  final s = (s_[0] * r + s_[1] * g + s_[2] * b).pow(1.0 / 3.0);

  final L = (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s);
  final aa = (1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s);
  final bb = (0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
  final c = math.sqrt(aa * aa + bb * bb);
  final h =
      c == 0 ? 0.0 : ((math.atan2(bb, aa) * 180 / math.pi) % 360 + 360) % 360;
  return (l: L.clamp(0, 1), c: c, h: h);
}

/// Converts OKLCh coordinates back to an opaque ARGB color (inverse route:
/// OKLCh → OKLab → linear sRGB → sRGB).
int oklchToArgb(double l, double c, double h) {
  final hh = h * math.pi / 180;
  final aa = c * math.cos(hh);
  final bb = c * math.sin(hh);
  // OKLab → LMS-cubed prelude.
  final lPrime = (l + 0.3963377774 * aa + 0.2158037573 * bb).pow(3.0);
  final mPrime = (l - 0.1055613458 * aa - 0.0638541728 * bb).pow(3.0);
  final sPrime = (l - 0.0894841775 * aa - 1.2914855480 * bb).pow(3.0);

  const r_ = [4.0767416621, -3.3077115913, 0.2309699292];
  const g_ = [-1.2684380046, 2.6097574011, -0.3413193965];
  const b_ = [-0.0041960863, -0.7034186147, 1.7076147010];
  int srgb(List<double> mat) {
    final v = mat[0] * lPrime + mat[1] * mPrime + mat[2] * sPrime;
    final v1 =
        v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1.0 / 2.4) - 0.055;
    return (v1 * 255).round().clamp(0, 255);
  }

  final rb = srgb(r_);
  final gb = srgb(g_);
  final bbChannel = srgb(b_);
  return 0xFF000000 | (rb << 16) | (gb << 8) | bbChannel;
}

extension on double {
  double pow(double exponent) => math.pow(this, exponent) as double;
}

/// Perceptually blends [from] toward [to] by [t] in `[0, 1]`: both colors are
/// converted to OKLCh, the lightness, chroma, and (shortest-arc) hue travel
/// together, and the result converts back to ARGB.
int oklchBlend(int from, int to, double t) {
  t = t.clamp(0.0, 1.0);
  final a = argbToOklch(from);
  final b = argbToOklch(to);
  var dh = b.h - a.h;
  if (dh > 180) dh -= 360;
  if (dh < -180) dh += 360;
  return oklchToArgb(
    a.l + (b.l - a.l) * t,
    a.c + (b.c - a.c) * t,
    a.h + dh * t,
  );
}

/// Linearly blends each ARGB channel from [from] toward [to] by [t] in
/// `[0, 1]`.
int blendArgb(int from, int to, double t) {
  t = t.clamp(0.0, 1.0);
  int channel(int argb, int shift) => (argb >> shift) & 0xFF;
  int mix(int shift) =>
      (channel(from, shift) + (channel(to, shift) - channel(from, shift)) * t)
          .round();
  return (mix(24) << 24) | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// The WCAG relative luminance of [argb].
double relativeLuminance(int argb) {
  double linear(int channel) {
    final v = channel / 255;
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linear((argb >> 16) & 0xFF) +
      0.7152 * linear((argb >> 8) & 0xFF) +
      0.0722 * linear(argb & 0xFF);
}

/// Formats [argb] as `#RRGGBB`, or `#AARRGGBB` when translucent.
String argbToHex(int argb) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  final rgb = '${two((argb >> 16) & 0xFF)}'
      '${two((argb >> 8) & 0xFF)}'
      '${two(argb & 0xFF)}';
  final a = (argb >>> 24) & 0xFF;
  return a == 0xFF ? '#$rgb' : '#${two(a)}$rgb';
}

/// Parses `#RGB`, `#RRGGBB`, `#AARRGGBB` (with or without `#`) into ARGB.
///
/// Throws [FormatException] when [hex] is not one of those shapes.
int hexToArgb(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) throw FormatException('Not a hex color: $hex');
  return int.parse(h, radix: 16);
}
