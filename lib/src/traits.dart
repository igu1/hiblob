/// The deterministic trait reader: names in, `[0, 1)` positions out.
///
/// Traits are addressed by string key. A name always produces the same value
/// for a given key, pins replace exactly the keys they name, and adding new
/// keys later never moves existing ones.
library;

import 'hash.dart';
import 'options.dart';

/// Every trait the layout reads, in roster order.
const List<String> traitKeys = [
  'shape',
  'hue',
  'tone',
  'body.r',
  'body.aspect',
  'eye.ratio',
  'eye.spacing',
  'eye.offset',
  'face.offset',
  'detail.a',
  'detail.b',
  'detail.c',
  'detail.phase',
  'nub.angle',
];

/// Reads the trait table for [name], with [options] pins applied.
///
/// When [HiblobOptions.normalize] is on, the name is trimmed and lowercased
/// before hashing, so `'  ADA '` and `'ada'` hash identically.
Map<String, double> traitsFor(String name,
    {HiblobOptions options = const HiblobOptions()}) {
  final seed = options.normalize ? name.trim().toLowerCase() : name;
  final traits = {for (final k in traitKeys) k: stream(seed, k)};
  for (final e in options.traits.entries) {
    if (traits.containsKey(e.key)) {
      traits[e.key] = e.value.clamp(0.0, 1.0);
    }
  }
  if (options.hue != null) {
    final h = ((options.hue! % 360) + 360) % 360;
    traits['hue'] = h / 360;
  }
  if (options.tone != null) {
    traits['tone'] = options.tone!.clamp(0.0, 0.999999).toDouble();
  }
  return traits;
}

/// Maps a position in `[0, 1]` onto the band table [bands] (each entry is
/// `(start, end)`, end-exclusive except for the final band).
String bandFor(double value, Map<String, (double, double)> bands) {
  for (final e in bands.entries) {
    final (start, end) = e.value;
    if (value >= start && value < end) return e.key;
  }
  return bands.keys.last;
}

/// The silhouette bands. Everyday shapes get wide bands; loud shapes are a
/// find. These tables are part of the frozen visual contract: changing a band
/// moves existing names to different silhouettes.
const Map<String, (double, double)> shapeBands = {
  'round': (0.00, 0.200),
  'organic': (0.200, 0.42),
  'boxy': (0.42, 0.550),
  'nub': (0.550, 0.650),
  'capsule': (0.650, 0.740),
  'hexagon': (0.740, 0.800),
  'triangle': (0.800, 0.860),
  'droplet': (0.860, 0.920),
  'cloud': (0.920, 0.965),
  'sun': (0.965, 1.010),
};

/// The tone bands, pale to ink, partitioned like the silhouette bands.
const Map<String, (double, double)> toneBands = {
  'pale': (0.0, 0.20),
  'soft': (0.20, 0.40),
  'mid': (0.40, 0.60),
  'deep': (0.60, 0.80),
  'ink': (0.80, 1.01),
};
