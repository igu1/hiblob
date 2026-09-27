/// Deterministic hashing of names into seeded trait streams.
///
/// Everything a hiblob is comes from these numbers. The same normalized name
/// always produces the same stream — on every platform and every Dart
/// implementation — because all arithmetic here is 32-bit integer math, which
/// behaves identically on the VM and on the web, where Dart `int` is a
/// double-backed 64-bit value that only guarantees exact 32-bit operations.
library;

import 'dart:convert';

/// Masks [x] to its low 32 bits.
int _mask32(int x) => x & 0xFFFFFFFF;

/// 32-bit integer multiply that stays exact on every platform.
int _imul(int a, int b) {
  final int al = a & 0xFFFF, ah = a >>> 16;
  final int bl = b & 0xFFFF, bh = b >>> 16;
  return _mask32(al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16));
}

/// FNV-1a (32-bit) over the UTF-8 bytes of [s].
int fnv1a32(String s) {
  var h = 0x811C9DC5;
  for (final int b in utf8.encode(s)) {
    h = _imul(h ^ b, 0x01000193);
  }
  return h;
}

/// A small, fast 32-bit PRNG (mulberry32) with a fixed, portable sequence.
class _Mulberry32 {
  int _state;
  _Mulberry32(this._state);

  int _next() {
    _state = _mask32(_state + 0x6D2B79F5);
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = _mask32(t ^ ((t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF));
    return _mask32(t ^ (t >>> 14));
  }

  /// The next value in `[0, 1)`.
  double nextDouble() => _next() / 4294967296.0;
}

/// The stream value for [key] derived from [seed], in `[0, 1)`.
///
/// Streams are addressed by string key rather than drawn from one sequential
/// state, so adding a new trait later never disturbs the values existing
/// traits read, and any single trait can be pinned without moving the others.
double stream(String seed, String key) =>
    _Mulberry32(fnv1a32(seed) ^ fnv1a32(key)).nextDouble();
