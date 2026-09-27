/// Options for the hiblob generator: backdrop, color pins, trait pins, and
/// the facial expression.
library;

import 'expressions.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Normalizes a name the way the generator hashes it: Unicode NFC
/// (canonical composition, so `'e'` + U+0301 and `'é'` are one name), trim,
/// and lowercase.
String normalizeSeed(String name) => unorm.nfc(name.trim().toLowerCase());

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

/// Keys [HiblobOptions.accessories] accepts, with the deterministic
/// per-name probability each accessory defaults to when unpinned.
abstract final class AccessoryKeys {
  /// Round frames over the eyes.
  static const String glasses = 'glasses';

  /// A brow fringe (hair band) across the top of the figure.
  static const String fringe = 'fringe';

  /// Soft blush discs beside the eyes.
  static const String blush = 'blush';

  /// Two antennae rising from the top of the head.
  static const String antennae = 'antennae';

  /// Every accessory key.
  static const List<String> all = [glasses, fringe, blush, antennae];

  /// The per-name draw probability of each accessory when unpinned; the
  /// layout reads `traits['shape']`-style streams for anything not in the
  /// pin map.
  static const Map<String, double> defaultProbabilities = {
    glasses: 0.30,
    fringe: 0.40,
    blush: 0.30,
    antennae: 0.12,
  };
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

  /// Accessory pins keyed by [AccessoryKeys]. A value of `1` forces the
  /// accessory on, `0` forces it off, and keys left out stay name-driven —
  /// each is drawn when the name's hash clears the accessory's default
  /// probability in [AccessoryKeys.defaultProbabilities].
  final Map<String, double> accessories;

  /// Whether a mouth is drawn. Expressions still shape the eyes when off.
  final bool mouth;

  /// Pins individual traits to the `[0, 1]` position the hash would otherwise
  /// have produced, keyed by trait name (for example `'shape'`,
  /// `'eye.ratio'`). Unknown keys are ignored.
  final Map<String, double> traits;

  /// Whether the name is normalized before hashing: Unicode NFC, trim, and
  /// lowercase.
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
    this.accessories = const {},
    this.mouth = true,
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
      _mapsEqual(other.accessories, accessories) &&
      _mapsEqual(other.traits, traits) &&
      other.mouth == mouth &&
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
      mouth,
      Object.hashAllUnordered(palette.entries),
      Object.hashAllUnordered(accessories.entries),
      Object.hashAllUnordered(traits.entries));

  static bool _mapsEqual(Map<String, Object> a, Map<String, Object> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
