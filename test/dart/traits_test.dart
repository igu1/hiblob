import 'package:test/test.dart';

import 'package:hiblob/src/hash.dart';
import 'package:hiblob/src/traits.dart';

const List<String> keys = [
  'shape',
  'hue',
  'tone',
  'body.r',
  'body.ratio',
  'body.x',
  'body.y',
  'body.n',
  'body.rot',
  'body.pts',
  'body.r0',
  'body.r1',
  'gaze.x',
  'gaze.y',
  'eye.rx',
  'eye.ratio',
  'eye.gap',
  'eye.n',
  'eye.lean',
  'eye.lean2',
];

List<double> vector(String seed) => [for (final k in keys) traitsFor(seed)(k)];

void main() {
  group('determinism', () {
    test('the same seed produces identical vectors', () {
      expect(vector('alain'), vector('alain'));
    });

    test('different seeds produce different vectors', () {
      expect(vector('alain'), isNot(vector('bob')));
    });

    test('adding a trait read cannot disturb existing traits', () {
      // The append-only namespace guarantee: a reader that asks for one more
      // key leaves every other key's value untouched.
      final before = traitsFor('alain');
      final t = traitsFor('alain');
      final double extra = stream(t.state, 'freckles.size');
      expect(extra, stream(before.state, 'freckles.size'));
      for (final k in keys) {
        expect(t(k), before(k));
      }
    });
  });

  group('normalization', () {
    test('case, whitespace and NFC form are equivalent', () {
      final base = vector('Alain@Example.com');
      expect(vector('alain@example.com'), base);
      expect(vector('  ALAIN@EXAMPLE.COM  '), base);
    });

    test('decomposed and precomposed accents agree', () {
      // "café": U+00E9 vs "e" + U+0301
      expect(vector('caf\u00e9'), vector('cafe\u0301'));
      expect(normalizeSeed('cafe\u0301'), 'caf\u00e9');
    });

    test('Final_Sigma follows the JS full lowercase mapping', () {
      // Word-initial and isolated sigmas keep the plain form; a sigma that
      // follows a cased letter and precedes none becomes the word-final ς.
      // These are pinned against the reference vectors, which were exported
      // from the JS core.
      expect(normalizeSeed('\u03A3'), '\u03C3'); // Σ -> σ
      expect(normalizeSeed(' \u03A3 '), '\u03C3');
      expect(normalizeSeed('\u03A3\u0301'), '\u03C3\u0301');
      expect(normalizeSeed('\u03A3\u03A3'), '\u03C3\u03C2'); // σς
      expect(normalizeSeed('\u039F\u03A3'), '\u03BF\u03C2'); // ΟΣ -> ος
      expect(normalizeSeed('\u039F\u03A3\u0394'), '\u03BF\u03C3\u03B4'); // οσδ
    });

    test('U+0130 keeps its combining dot like JS', () {
      expect(normalizeSeed('\u0130'), 'i\u0307');
    });

    test(
        'simple lowercase predates newer Unicode case pairs (documented deviation)',
        () {
      // Dart's simple lowercase data predates Georgian Mtavruli (U+1C90):
      // JavaScript maps it to U+10D0, Dart keeps the uppercase. Recorded as a
      // documented deviation — the parities this matters for (Latin, Greek,
      // Cyrillic, Latin-extended) match. If a later Dart native Unicode-data
      // update makes this assertion fail, the deviation is closed.
      expect(normalizeSeed('\u1C90'), '\u1C90');
    });

    test('normalize: false hashes the raw string', () {
      double v(String seed, {bool normalize = true}) =>
          traitsFor(seed, normalize: normalize)('hue');
      // Raw casing hashes differently from lowercased input...
      expect(v('Alain', normalize: false), isNot(v('alain', normalize: false)));
      // ...and both differ from what the normalized seed hashes to.
      expect(v('Alain', normalize: false), isNot(v('alain')));
      expect(v('  ALAIN  ', normalize: false), isNot(v('alain')));
    });

    test('BOM-only and empty seeds normalize to the empty string', () {
      expect(normalizeSeed(''), '');
      expect(normalizeSeed('   '), '');
      expect(normalizeSeed('\uFEFF'), '\uFEFF'.trim());
    });
  });

  group('non-ascii', () {
    test('handles multi-byte and astral-plane seeds', () {
      for (final seed in ['日本語', 'Ελλάδα', '🦊🐻', 'أحمد', '🇫🇷']) {
        final double v = stream(seedState(seed), 'hue');
        expect(v.isFinite && v >= 0 && v < 1, isTrue, reason: seed);
      }
    });

    test('emoji differing only in the low surrogate are distinguished', () {
      // U+1F98A and U+1F98B share a high surrogate; hashing UTF-16 units
      // naively still separates these, but hashing UTF-8 bytes must too.
      expect(vector('🦊'), isNot(vector('🦋')));
    });

    test('astral seeds are stable across repeated calls', () {
      expect(vector('🦊🐻'), vector('🦊🐻'));
    });
  });

  group('uint32 semantics', () {
    test('imul reproduces Math.imul on known products', () {
      // Math.imul(0x1234, 0x5678) = 0x5CB36AA0? Verified against the JS
      // reference: (0x1234 * 0x5678) mod 2^32.
      expect(imul(0x1234, 0x5678), 0x1234 * 0x5678);
      expect(imul(-21, 5), -105);
      // Overflow wraps: Math.imul(0xFFFFFFFF, 2) = -2.
      expect(imul(0xFFFFFFFF, 2), -2);
      expect(imul(0x10000, 0x10000), 0);
      // Sign behavior: Math.imul(-1, -1) = 1.
      expect(imul(-1, -1), 1);
    });

    test('the stream stays in [0, 1) for a wide seed sweep', () {
      for (var i = 0; i < 2000; i++) {
        final double v = stream(seedState('sweep-$i'), 'hue');
        expect(v >= 0 && v < 1, isTrue, reason: 'sweep-$i -> $v');
      }
    });
  });

  group('reading', () {
    test('an override replaces exactly its own key', () {
      final base = traitsFor('alain');
      final over = traitsFor('alain', overrides: {'eye.gap': 0.82});

      expect(over('eye.gap'), 0.82);
      for (final k in ['shape', 'body.r', 'eye.rx', 'hue', 'tone']) {
        expect(over(k), base(k));
      }
    });

    test('zero is a value, not an absence', () {
      final t = traitsFor('alain', overrides: {'eye.rx': 0.0});
      expect(t('eye.rx'), 0.0);
      expect(t.numIn('eye.rx', 0.075, 0.105), 0.075);
    });

    test('the derived readers use the override', () {
      final t = traitsFor('alain', overrides: {
        'a': 0.0,
        'b': 0.5,
        'c': 0.999999,
      });
      expect(t.numIn('a', 10, 20), 10);
      expect(t.intIn('b', 0, 10), 5);
      expect(t.pick('c', ['x', 'y', 'z']), 'z');
      expect(t.jitter('a', 4), -4);
      expect(t.boolIn('a'), isTrue);
      expect(t.boolIn('c'), isFalse);
    });

    test('out-of-range values are clamped instead of trusted', () {
      final t = traitsFor('alain', overrides: {
        'high': 1.0,
        'way': 99.0,
        'low': -3.0,
        'nan': double.nan,
        'inf': double.infinity,
      });

      // Exactly 1 is the one that looks reasonable and indexes off the end.
      for (final k in ['high', 'way', 'inf']) {
        expect(t.pick(k, ['x', 'y', 'z']), 'z');
        expect(t.intIn(k, 6, 8), 8);
        expect(t(k), lessThan(1));
      }
      for (final k in ['low', 'nan']) {
        expect(t(k), 0.0);
        expect(t.pick(k, ['x', 'y', 'z']), 'x');
      }
    });

    test('a list override lets the key hash choose among the listed values',
        () {
      final t = traitsFor('alain', overrides: {
        'eye.gap': [0.3, 0.9],
      });
      final double hashed = stream(seedState('alain'), 'eye.gap');
      final int index = (hashed * 2).floor();
      expect(t('eye.gap'), index == 0 ? 0.3 : 0.9);
    });

    test('an empty list override is the same as omitting the key', () {
      final t = traitsFor('alain', overrides: {
        'eye.gap': <double>[],
      });
      expect(t('eye.gap'), stream(seedState('alain'), 'eye.gap'));
    });
  });
}
