/// Options for the hiblob generator: backdrop, color pins, trait pins, and
/// the facial expression.
library;

import 'expressions.dart';

/// The backdrop plates a hiblob can sit on.
enum Backdrop {
  /// No plate — the figure alone.
  none,

  /// A rounded square (superellipse) plate.
  squircle,

  /// A circular plate.
  circle,

  /// A square plate with slightly softened corners.
  square,
}

/// Keys [HiblobOptions.palette] accepts. Each value is a hex color string.
abstract final class PaletteKeys {
  /// The backdrop plate color.
  static const String bg = 'bg';

  /// The body color.
  static const String head = 'head';

  /// The eye color.
  static const String eye = 'eye';
}

/// Immutable options for one hiblob.
///
/// Everything is optional: with no options, the name alone decides the whole
/// figure. Pins ([hue], [tone], [traits], [palette]) override the name for
/// exactly the axes they name — every other axis stays name-driven.
class HiblobOptions {
  /// The backdrop plate drawn behind the figure.
  final Backdrop background;

  /// Pins the color hue, in degrees `0..360`. `null` leaves it name-driven.
  final double? hue;

  /// Pins the authored lightness band, in `[0, 1)`. `null` leaves it
  /// name-driven.
  final double? tone;

  /// Overrides selected colors by [PaletteKeys] — hex strings like
  /// `'#1E293B'`.
  final Map<String, String> palette;

  /// Pins individual traits to the `[0, 1]` position the hash would otherwise
  /// have produced, keyed by trait name (for example `'shape'`,
  /// `'eye.ratio'`). Unknown keys are ignored.
  final Map<String, double> traits;

  /// Whether the name is normalized (trimmed and lowercased) before hashing.
  final bool normalize;

  /// Whether the contrast floor between body and eyes is enforced.
  final bool contrast;

  /// The facial expression applied on top of the pose.
  final Expression expression;

  const HiblobOptions({
    this.background = Backdrop.none,
    this.hue,
    this.tone,
    this.palette = const {},
    this.traits = const {},
    this.normalize = true,
    this.contrast = true,
    this.expression = idle,
  });

  @override
  bool operator ==(Object other) =>
      other is HiblobOptions &&
      other.background == background &&
      other.hue == hue &&
      other.tone == tone &&
      _mapsEqual(other.palette, palette) &&
      _mapsEqual(other.traits, traits) &&
      other.normalize == normalize &&
      other.contrast == contrast &&
      other.expression == expression;

  @override
  int get hashCode => Object.hash(
      background,
      hue,
      tone,
      normalize,
      contrast,
      expression,
      Object.hashAllUnordered(palette.entries),
      Object.hashAllUnordered(traits.entries));

  static bool _mapsEqual(Map<String, Object> a, Map<String, Object> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
