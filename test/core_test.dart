import 'dart:math' as math;

import 'package:hiblob/hiblob.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample names sweeping different scripts, casings, and lengths.
final sampleNames = [
  '',
  'a',
  'ada',
  'ada@example.com',
  'Ada Lovelace',
  '  spaced  ',
  'GRACE',
  'hopper-42',
  'zoë',
  'Zoë',
  '命',
  'λ-man',
  '🦊',
  'octo-cat',
  'marianna.delores.ellington@sub.example.co.uk',
  'x' * 200,
];

void main() {
  group('traitsFor', () {
    test('is deterministic per name', () {
      for (final name in sampleNames) {
        expect(traitsFor(name), traitsFor(name));
      }
    });

    test('differs across names', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(traitsFor('name-$i')['shape'].toString());
      }
      expect(seen.length, greaterThan(5));
    });

    test('normalizes trim and case when normalize is on', () {
      final a = traitsFor('  ADA ', options: const HiblobOptions());
      final b = traitsFor('ada', options: const HiblobOptions());
      expect(a, b);
    });

    test('normalization can be turned off', () {
      final a =
          traitsFor('  ADA ', options: const HiblobOptions(normalize: false));
      final b =
          traitsFor('ada', options: const HiblobOptions(normalize: false));
      expect(a, isNot(b));
    });

    test('pins only the keys they name', () {
      final pinned = traitsFor('ada',
          options: const HiblobOptions(traits: {'shape': 0.0}));
      final plain = traitsFor('ada');
      expect(pinned['shape'], 0.0);
      for (final key in traitKeys) {
        if (key != 'shape') expect(pinned[key], plain[key]);
      }
    });

    test('hue and tone pins clamp and wrap', () {
      final t =
          traitsFor('ada', options: const HiblobOptions(hue: 760, tone: 2.0));
      expect(t['hue']! * 360, closeTo(40, 1e-9));
      expect(t['tone'], 0.999999);
    });
  });

  group('shape bands', () {
    test('every band is reachable across many names', () {
      final shapes = <String>{};
      for (var i = 0; i < 2000; i++) {
        shapes.add(resolve('user-$i').shape);
      }
      expect(shapes, shapeBands.keys.toSet());
    });

    test('band edges resolve as documented', () {
      String at(double v) =>
          resolve('ada', options: HiblobOptions(traits: {'shape': v})).shape;
      expect(at(0.0), 'round');
      expect(at(0.199), 'round');
      expect(at(0.2), 'organic');
      expect(at(0.965), 'sun');
      expect(at(1.0), 'sun');
    });

    test('everyday shapes stay everyday, loud ones stay rare', () {
      final counts = <String, int>{};
      for (var i = 0; i < 4000; i++) {
        final s = resolve('u$i').shape;
        counts[s] = (counts[s] ?? 0) + 1;
      }
      expect(counts['round']! + counts['organic']!, greaterThan(4000 * 0.30));
      expect(counts['sun']!, lessThan(4000 * 0.08));
    });
  });

  group('resolve', () {
    test('is deterministic: same name, same geometry and palette', () {
      for (final name in sampleNames) {
        final a = resolve(name);
        final b = resolve(name);
        expect(a.body.map((p) => p.toPathData()).toList(),
            b.body.map((p) => p.toPathData()).toList());
        expect(a.headColor, b.headColor);
        expect(a.eyeColor, b.eyeColor);
      }
    });

    test('two eyes in every figure, left before right', () {
      for (final name in sampleNames) {
        final figure = resolve(name);
        expect(figure.eyes.length, 2);
        expect(figure.eyes[0].cx, lessThan(figure.eyes[1].cx));
      }
    });

    test('eyes never fuse', () {
      for (final name in sampleNames) {
        final figure = resolve(name);
        final gap = figure.eyes[1].cx - figure.eyes[0].cx;
        expect(gap, greaterThan(2.0));
      }
    });

    test('every silhouette keeps its geometry inside the view box', () {
      for (final shape in shapeBands.keys) {
        for (var i = 0; i < 80; i++) {
          final figure = resolve('s$i',
              options: HiblobOptions(traits: {'shape': _bandCenter(shape)}));
          for (final path in figure.body) {
            final b = path.bounds;
            expect(b.minX, greaterThanOrEqualTo(0.5),
                reason: '$shape name s$i minX ${b.minX}');
            expect(b.maxX, lessThanOrEqualTo(99.5),
                reason: '$shape name s$i maxX ${b.maxX}');
            expect(b.minY, greaterThanOrEqualTo(0.5),
                reason: '$shape name s$i minY ${b.minY}');
            expect(b.maxY, lessThanOrEqualTo(99.5),
                reason: '$shape name s$i maxY ${b.maxY}');
          }
        }
      }
    });

    test('the whole roster of expressions resolves for every shape', () {
      for (final shape in shapeBands.keys) {
        final options = HiblobOptions(traits: {'shape': _bandCenter(shape)});
        for (final expression in expressions) {
          final figure = resolve('x',
              options: HiblobOptions(
                  traits: options.traits, expression: expression));
          expect(figure.eyes.length, 2);
        }
      }
    });

    test('expressions change the eyes', () {
      ResolvedHiblob withExpression(Expression e) => resolve('ada',
          options: HiblobOptions(traits: const {'shape': 0.0}, expression: e));
      final idleData = withExpression(idle).eyes[0].marks.toPathData();
      final happyData = withExpression(happy).eyes[0].marks.toPathData();
      final loveData = withExpression(love).eyes[0].marks.toPathData();
      expect(happyData, isNot(idleData));
      expect(loveData, isNot(idleData));
    });

    test('love eyes carry more marks than idle eyes', () {
      final loved = resolve('ada',
          options:
              const HiblobOptions(expression: love, traits: {'shape': 0.0}));
      final idleFigure =
          resolve('ada', options: const HiblobOptions(traits: {'shape': 0.0}));
      expect(loved.eyes[0].marks.length,
          greaterThan(idleFigure.eyes[0].marks.length));
    });

    test('wink closes exactly one eye', () {
      final w = resolve('ada', options: const HiblobOptions(expression: wink));
      expect(w.eyes[0].strokeOnly, isFalse);
      expect(w.eyes[1].strokeOnly, isTrue);
    });
  });

  group('palette', () {
    test('pinned hue and tone give one stable head color', () {
      final colors = <int>{
        for (final name in ['a', 'b', 'c', 'd'])
          resolve(name,
              options: const HiblobOptions(
                  hue: 210,
                  tone: 0.5,
                  traits: {'detail.b': 0.5, 'detail.c': 0.5})).headColor
      };
      expect(colors.length, 1);
    });

    test('contrast floor holds across many names', () {
      for (var i = 0; i < 500; i++) {
        final figure = resolve('c$i');
        final lh = relativeLuminance(figure.headColor);
        final le = relativeLuminance(figure.eyeColor);
        expect((lh - le).abs(), greaterThanOrEqualTo(0.30),
            reason: 'name c$i head ${argbToHex(figure.headColor)} '
                'eye ${argbToHex(figure.eyeColor)}');
      }
    });

    test('palette overrides win', () {
      final figure = resolve('ada',
          options: const HiblobOptions(palette: {
            PaletteKeys.head: '#FF0000',
            PaletteKeys.eye: '#00FF00',
            PaletteKeys.bg: '#0000FF',
          }, background: Backdrop.circle));
      expect(figure.headColor, 0xFFFF0000);
      expect(figure.eyeColor, 0xFF00FF00);
      expect(figure.backdropColor, 0xFF0000FF);
    });

    test('backdrops are drawn only when asked for', () {
      expect(resolve('ada').backdrop, isNull);
      expect(
          resolve('ada',
                  options: const HiblobOptions(background: Backdrop.circle))
              .backdrop,
          isNotNull);
    });

    test('hex helpers round-trip', () {
      expect(argbToHex(0xFF1E293B), '#1E293B');
      expect(hexToArgb('#1E293B'), 0xFF1E293B);
      expect(hexToArgb('1E293B'), 0xFF1E293B);
      expect(hexToArgb('#129'), 0xFF112299);
      expect(hexToArgb('#801E293B') >> 24, 0x80);
    });
  });

  group('motion', () {
    test('is deterministic', () {
      final seeds = motionSeedsFor('ada');
      expect(motionAt(seeds, 1234.5), motionAt(seeds, 1234.5));
    });

    test('differs per name', () {
      final a = motionAt(motionSeedsFor('a'), 1000);
      final b = motionAt(motionSeedsFor('b'), 1000);
      expect(a == b, isFalse);
    });

    test('starts blink-free', () {
      for (var i = 0; i < 100; i++) {
        expect(motionAt(motionSeedsFor('m$i'), 0).blink, 0.0);
      }
    });

    test('blinks somewhere within a couple of periods', () {
      final seeds = motionSeedsFor('ada');
      var sawBlink = false;
      for (var ms = 0.0; ms < seeds.blinkPeriod * 2500; ms += 16) {
        if (motionAt(seeds, ms).blink > 0.5) sawBlink = true;
      }
      expect(sawBlink, isTrue);
    });

    test('stays in bounds', () {
      for (var i = 0; i < 50; i++) {
        final seeds = motionSeedsFor('b$i');
        for (var ms = 0.0; ms < 12000; ms += 16) {
          final f = motionAt(seeds, ms, ramp: 1);
          expect(f.blink, inInclusiveRange(0, 1));
          expect(f.gazeX.abs(), lessThanOrEqualTo(2.0));
          expect(f.gazeY.abs(), lessThanOrEqualTo(2.0));
          expect(f.bodyY.abs(), lessThanOrEqualTo(4.5));
          expect(f.bodyScaleY, inInclusiveRange(0.95, 1.05));
        }
      }
    });

    test('is continuous frame to frame', () {
      final seeds = motionSeedsFor('ada');
      var prev = motionAt(seeds, 0, ramp: 1);
      for (var ms = 16.0; ms < 6000; ms += 16) {
        final f = motionAt(seeds, ms, ramp: 1);
        expect((f.bodyY - prev.bodyY).abs(), lessThan(0.5));
        expect((f.gazeX - prev.gazeX).abs(), lessThan(0.6));
        expect((f.blink - prev.blink).abs(), lessThan(0.6));
        prev = f;
      }
    });

    test('the ramp quiets ambient motion', () {
      final seeds = motionSeedsFor('ada');
      double sweep(double ramp) {
        var total = 0.0;
        for (var ms = 0.0; ms < 6000; ms += 16) {
          total += motionAt(seeds, ms, ramp: ramp).bodyY.abs();
        }
        return total;
      }

      expect(sweep(0), lessThan(sweep(1) * 0.75));
    });
  });

  group('geometry primitives', () {
    test('path data is stable and equality follows it', () {
      final a = circle(50, 50, 20);
      final b = circle(50, 50, 20);
      final c = circle(50, 50, 21);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.toPathData(), contains('M'));
      expect(a.toPathData(), contains('C'));
    });

    test('bounds reflect the geometry', () {
      final b = circle(50, 50, 20).bounds;
      expect(b.minX, closeTo(30, 0.01));
      expect(b.maxX, closeTo(70, 0.01));
      expect(b.minY, closeTo(30, 0.01));
      expect(b.maxY, closeTo(70, 0.01));
    });

    test('superellipse with n=2 approximates a circle', () {
      final se = superellipse(50, 50, 20, 20, 2).bounds;
      final c = circle(50, 50, 20).bounds;
      expect(se.minX, closeTo(c.minX, 0.5));
      expect(se.maxX, closeTo(c.maxX, 0.5));
    });
  });
}

/// The center of a band, so a pinned trait lands mid-band.
double _bandCenter(String shape) {
  final (start, end) = shapeBands[shape]!;
  return math.min((start + end) / 2, 0.999999);
}

extension _PathData on Iterable<GeometryPath> {
  List<String> toPathData() => map((p) => p.toPathData()).toList();
}
