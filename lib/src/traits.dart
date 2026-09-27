/// Trait reading.
///
/// The deterministic trait reader.
///
/// Every value is addressed by a string key rather than drawn from a
/// sequential stream, so trait keys are an append-only namespace: introducing
/// a new key in a later version leaves every other trait — and therefore every
/// existing hiblob — untouched.
///
/// The one thing that is NOT free to change is the contents of a `pick` array,
/// since option index is part of the mapping. Those are frozen per major.
library;

import 'hash.dart';

/// Overrides are clamped rather than trusted.
///
/// `pick` and [Traits.intIn] index and floor, so a value of exactly 1 selects
/// one past the end of a `pick` array and one past `max` — out-of-range
/// options and counts, from an input that looks entirely reasonable to whoever
/// typed it. NaN falls to 0 through the same comparison, so a bad parse
/// renders a hiblob instead of a stack of NaNs.
///
/// Each value is the position in [0, 1) that the hash would otherwise have
/// produced — the same units the layout reads, which makes this a complete
/// configuration surface rather than a set of escape hatches. A [num] pins the
/// key to one outcome; a `List<num>` means "any of these", with the key's own
/// hash choosing among them; an empty list is the same as omitting the key.
typedef TraitOverrides = Map<String, Object>;

/// A trait reader over one hashed seed.
class Traits {
  /// The state the seed hashed into, from [seedState].
  final int state;

  final Map<String, Object>? _overrides;

  /// Constructs a reader directly from a hashed [state].
  ///
  /// Prefer [traitsFor], which hashes and normalizes the seed.
  Traits(this.state, [Map<String, Object>? overrides]) : _overrides = overrides;

  /// Uniform float in [0, 1).
  double call(String key) {
    final Object? v = _overrides?[key];
    double? o;
    if (v is List) {
      // A list is "any of these": the key's own hash is what picks from it —
      // the same number that would have been the value, spent on the index
      // instead. An empty list selects nothing and falls through to the hash,
      // which is deliberate: "nothing selected" and "not configured" are the
      // same request.
      if (v.isNotEmpty) {
        final int index = (stream(state, key) * v.length).floor();
        final Object? chosen = v[index];
        if (chosen != null) o = (chosen as num).toDouble();
      }
    } else if (v is num) {
      o = v.toDouble();
    }
    // Not `?? o` on the whole expression: an override of 0 is a legitimate
    // value — it is the bottom of every range — and must not fall through to
    // the hash. The clamp runs over a list's chosen element too, so a bad
    // number is clamped wherever it was written.
    if (o == null) return stream(state, key);
    if (o > 0) return o < 1 ? o : 0.999999;
    return 0.0;
  }

  /// Uniform float in [min, max).
  ///
  /// Named `numIn` rather than the JS core's `t.num` because a Dart member
  /// cannot shadow the builtin `num` type (same for `intIn`/`boolIn`).
  double numIn(String key, double min, double max) =>
      min + call(key) * (max - min);

  /// Uniform integer from `min` through `max`, inclusive.
  int intIn(String key, int min, int max) =>
      min + (call(key) * (max - min + 1)).floor();

  /// Uniform choice. Appending to `options` remaps existing seeds — frozen
  /// per major.
  T pick<T>(String key, List<T> options) =>
      options[(call(key) * options.length).floor()];

  /// True with probability `p`.
  bool boolIn(String key, [double p = 0.5]) => call(key) < p;

  /// Symmetric jitter in [-amount, amount).
  double jitter(String key, double amount) => (call(key) * 2 - 1) * amount;
}

/// Builds the trait reader for a seed.
///
/// The seed is normalized (NFC, trim, lowercase) unless [normalize] is false;
/// [overrides] pin individual trait keys, keyed exactly as the layout reads
/// them — `{"eye.gap": 0.82}`.
Traits traitsFor(
  String seed, {
  bool normalize = true,
  Map<String, Object>? overrides,
}) =>
    Traits(seedState(seed, normalize: normalize), overrides);
