import 'package:hiblob/hiblob.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// The cross-language parity gate: everything the fixture's comparison rules
/// mark exact must match exactly; trig-derived layout floats are compared
/// under the documented relative tolerance.
void main() {
  final List<dynamic> hashVectors = vectors['hash'] as List<dynamic>;
  final List<dynamic> overrideVectors = vectors['overrides'] as List<dynamic>;
  final List<dynamic> paletteVectors = vectors['palette'] as List<dynamic>;
  final List<dynamic> cases = vectors['cases'] as List<dynamic>;

  group('hash vectors', () {
    test('normalization agrees byte for byte', () {
      for (final v in hashVectors) {
        final m = v as Map<String, dynamic>;
        expect(normalizeSeed(m['seed'] as String), m['normalized'],
            reason: 'normalizeSeed(${m['seed']})');
      }
    });

    test('seed states agree exactly', () {
      for (final v in hashVectors) {
        final m = v as Map<String, dynamic>;
        expect(seedState(m['seed'] as String), m['state'],
            reason: 'seedState(${m['seed']})');
      }
    });

    test('trait streams agree exactly', () {
      for (final v in hashVectors) {
        final m = v as Map<String, dynamic>;
        final int state = m['state'] as int;
        final streams = m['streams'] as Map<String, dynamic>;
        for (final entry in streams.entries) {
          final double expected = (entry.value as num).toDouble();
          final double actual = stream(state, entry.key);
          // Same uint32 / 2^32 division on both sides — bit-identical, not
          // approximate.
          expect(actual == expected, isTrue,
              reason: 'stream(${m['seed']}, ${entry.key})');
        }
      }
    });
  });

  group('override vectors', () {
    test('override reads agree exactly', () {
      for (final v in overrideVectors) {
        final m = v as Map<String, dynamic>;
        final overrides = (m['overrides'] as Map<String, dynamic>).map(
          (k, value) {
            if (value is List) {
              return MapEntry(
                  k, [for (final e in value) (e as num).toDouble()]);
            }
            return MapEntry(k, (value as num).toDouble());
          },
        );
        final t = traitsFor(
          m['seed'] as String,
          overrides: overrides.isEmpty ? null : overrides,
        );
        final values = m['values'] as Map<String, dynamic>;
        for (final entry in values.entries) {
          final double expected = (entry.value as num).toDouble();
          final double actual = t(entry.key);
          expect(actual == expected, isTrue,
              reason: '${m['seed']} ${entry.key}: $actual != $expected');
        }
      }
    });
  });

  group('palette vectors', () {
    test('ramp values agree within tolerance; hex agrees exactly', () {
      for (final v in paletteVectors) {
        final m = v as Map<String, dynamic>;
        final double hue = (m['hue'] as num).toDouble();
        final double tone = (m['tone'] as num).toDouble();
        final hex = m['hex'] as Map<String, dynamic>;

        final enforced = palette(hue, true, tone);
        expect(enforced['bg'], hex['bg'], reason: 'bg hex h=$hue t=$tone');
        expect(enforced['head'], hex['head'],
            reason: 'head hex h=$hue t=$tone');
        expect(enforced['eye'], hex['eye'], reason: 'eye hex h=$hue t=$tone');

        final unenforced = ramp(hue, false, tone);
        final raw = m['rampUnenforced'] as Map<String, dynamic>;
        for (final key in ['bg', 'head', 'eye']) {
          final expected = raw[key] as Map<String, dynamic>;
          final Oklch actual = unenforced[key]!;
          expect(
              closeEnough(actual.l, (expected['l'] as num).toDouble()), isTrue,
              reason: '$key.l h=$hue t=$tone');
          expect(
              closeEnough(actual.c, (expected['c'] as num).toDouble()), isTrue,
              reason: '$key.c h=$hue t=$tone');
          expect(
              closeEnough(actual.h, (expected['h'] as num).toDouble()), isTrue,
              reason: '$key.h h=$hue t=$tone');
        }
      }
    });
  });

  group('layout cases', () {
    test('fixture covers every silhouette band with its quota', () {
      final counts = vectors['meta']['shapeCounts'] as Map<String, dynamic>;
      expect(counts.length, 10);
      for (final entry in counts.entries) {
        expect(entry.value, greaterThanOrEqualTo(25),
            reason: 'band ${entry.key}');
      }
    });

    test('all layout cases agree with the reference vectors', () {
      _checkAllCases(cases);
    });
  });
}

void _checkAllCases(List<dynamic> cases) {
  String? firstFailure;
  var failures = 0;
  for (final c in cases) {
    final m = c as Map<String, dynamic>;
    final String? reason = _checkCase(m);
    if (reason != null) {
      failures++;
      firstFailure ??= 'seed=${m['seed']} opts=${m['options']}: $reason';
    }
  }
  expect(failures, 0, reason: firstFailure);
}

String? _checkCase(Map<String, dynamic> m) {
  final String seed = m['seed'] as String;
  final HiblobOptions opts =
      optionsFromJson(m['options'] as Map<String, dynamic>);
  final HiblobLayout l = layoutFor(seed, opts);
  if (l.shape != m['shape']) return '${l.shape} != ${m['shape']}';

  final body = m['body'] as Map<String, dynamic>;
  if (!closeEnough(l.body.cx, (body['cx'] as num).toDouble())) return 'body.cx';
  if (!closeEnough(l.body.cy, (body['cy'] as num).toDouble())) return 'body.cy';
  if (!closeEnough(l.body.rx, (body['rx'] as num).toDouble())) return 'body.rx';
  if (!closeEnough(l.body.ry, (body['ry'] as num).toDouble())) return 'body.ry';
  if (!closeEnough(l.body.n, (body['n'] as num).toDouble())) return 'body.n';
  if (!closeEnough(l.body.rot, (body['rot'] as num).toDouble())) {
    return 'body.rot';
  }

  final radii = (body['radii'] as List).cast<num>();
  if (l.body.radii.length != radii.length) return 'radii.length';
  for (var i = 0; i < radii.length; i++) {
    if (!closeEnough(l.body.radii[i], radii[i].toDouble())) return 'radii[$i]';
  }
  if (body['sides'] != null && l.body.sides != body['sides']) return 'sides';
  if (body['round'] != null &&
      !closeEnough(l.body.round!, (body['round'] as num).toDouble())) {
    return 'round';
  }

  expectEllipse(l.face.cx, l.face.cy, l.face.rx, l.face.ry,
      m['face'] as Map<String, dynamic>, 'face');

  final eyes = m['eyes'] as List<dynamic>;
  if (l.eyes.length != eyes.length) return 'eyes.length';
  for (var i = 0; i < eyes.length; i++) {
    expectEye(l.eyes[i], eyes[i] as Map<String, dynamic>, 'eye$i');
  }

  final petals = m['petals'] as List<dynamic>;
  if (l.petals.length != petals.length) return 'petals.length';
  for (var i = 0; i < petals.length; i++) {
    final p = petals[i] as Map<String, dynamic>;
    if (!closeEnough(l.petals[i].cx, (p['cx'] as num).toDouble())) {
      return 'petals[$i].cx';
    }
    if (!closeEnough(l.petals[i].cy, (p['cy'] as num).toDouble())) {
      return 'petals[$i].cy';
    }
    if (!closeEnough(l.petals[i].r, (p['r'] as num).toDouble())) {
      return 'petals[$i].r';
    }
  }

  // Path data: r2-rounded on both sides, so exact.
  final extra = (m['extra'] as List).cast<String>();
  if (l.extra.length != extra.length) return 'extra.length';
  for (var i = 0; i < extra.length; i++) {
    if (l.extra[i].toPathData() != extra[i]) return 'extra[$i]';
  }
  if (l.bodyPath().toPathData() != m['bodyPath']) return 'bodyPath';
  final eyePaths = (m['eyePaths'] as List).cast<String>();
  final actualEyes = l.eyePaths();
  for (var i = 0; i < eyePaths.length; i++) {
    if (actualEyes[i].toPathData() != eyePaths[i]) return 'eyePaths[$i]';
  }

  final pal = m['palette'] as Map<String, dynamic>;
  final (_, resolved) = partsFor(seed, opts);
  if (resolved['bg'] != pal['bg']) return 'palette.bg';
  if (resolved['head'] != pal['head']) return 'palette.head';
  if (resolved['eye'] != pal['eye']) return 'palette.eye';
  return null;
}
