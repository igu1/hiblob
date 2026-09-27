/// Color math for the hiblob palette.
///
/// Colors are authored in HSL, carried as 32-bit ARGB ints, compared with the
/// WCAG relative-luminance formula when the contrast floor is on, and blended
/// for expression tints. No `dart:ui` — the Flutter layer converts.
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
