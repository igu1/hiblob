import 'dart:math' as math;

import 'package:test/test.dart';

import 'package:hiblob/hiblob.dart';

void main() {
  group('tone bands', () {
    test('the band edges select the authored swatches', () {
      // Cumulative edges: 0.2 pastel, 0.36 pale, 0.62 mid, 0.8 deep, 0.93
      // bright, 1.0 ink. A value on an edge belongs to the next band.
      final pastel = ramp(120, false, 0.19)['head']!;
      expect(ramp(120, false, 0.0)['head']!.l, pastel.l);
      expect(ramp(120, false, 0.2)['head']!.l, 0.9);
      expect(ramp(120, false, 0.35)['head']!.l, 0.9);
      expect(ramp(120, false, 0.36)['head']!.l, 0.73);
      expect(ramp(120, false, 0.62)['head']!.l, 0.62);
      expect(ramp(120, false, 0.8)['head']!.l, 0.87);
      expect(ramp(120, false, 0.93)['head']!.l, 0.34);
    });

    test('an exact tone of 1 renders what 0 renders', () {
      // Half-open edges: 1 sits on the top edge and falls back to the first
      // swatch. Reach for ink with 0.999.
      expect(palette(90, true, 1), palette(90, true, 0));
      expect(palette(90, true, 0.999), isNot(palette(90, true, 0)));
    });
  });

  group('contrast enforcement', () {
    test('the floors hold across a dense hue and tone sweep', () {
      for (var h = 0; h < 360; h += 6) {
        for (final double tone in const <double>[
          0,
          0.15,
          0.3,
          0.45,
          0.6,
          0.75,
          0.9,
          0.999
        ]) {
          final r = ramp(h.toDouble(), true, tone);
          expect(contrast(r['head']!, r['bg']!), greaterThanOrEqualTo(1.25),
              reason: 'head/bg h=$h t=$tone');
          expect(contrast(r['eye']!, r['head']!), greaterThanOrEqualTo(4.5),
              reason: 'eye/head h=$h t=$tone');
          // The surface floor: the body must stay visible on a dark page.
          expect(contrast(r['head']!, darkSurface),
              greaterThanOrEqualTo(surfaceFloor),
              reason: 'head/surface h=$h t=$tone');
        }
      }
    });

    test('contrast: false skips the floors but keeps the ramp', () {
      // The surface floor lives in the ramp itself and is never skipped; what
      // `contrast: false` skips is the FLOORS chain. The head/backdrop 1.25
      // floor is the one that bites on the pale swatches at some hues.
      var headHexChanged = 0;
      var rawHeadFail = 0;
      for (var h = 0; h < 360; h += 5) {
        for (final double tone in const <double>[
          0,
          0.1,
          0.2,
          0.35,
          0.5,
          0.61,
          0.8,
          0.93,
          0.999
        ]) {
          final e = ramp(h.toDouble(), true, tone);
          final r = ramp(h.toDouble(), false, tone);
          // Compare serialized values, not object identity.
          if (toHex(e['head']!) != toHex(r['head']!)) headHexChanged++;
          if (contrast(r['head']!, r['bg']!) < 1.25) rawHeadFail++;
          // Enforcement never leaves a failing pair behind.
          expect(contrast(e['head']!, e['bg']!), greaterThanOrEqualTo(1.25),
              reason: 'h=$h t=$tone');
        }
      }
      expect(rawHeadFail, greaterThan(0));
      expect(headHexChanged, greaterThan(0));
    });

    test('ensureContrast walks in the direction it is already leaning', () {
      final bg = const Oklch(0.9, 0.02, 120);
      final fg = const Oklch(0.72, 0.05, 120);
      // The pair starts failing, or there is nothing to walk.
      expect(contrast(fg, bg), lessThan(3));
      final fixed = ensureContrast(fg, bg, 3);
      // A dark foreground on a light background gets darker, not lighter.
      expect(fixed.l, lessThan(fg.l));
      expect(contrast(fixed, bg), greaterThanOrEqualTo(3));
    });
  });

  group('gamut', () {
    test('out-of-gamut colors reduce chroma instead of clipping', () {
      // A vivid blue at high chroma is out of sRGB gamut; resolution must
      // lower chroma until it fits, keeping the hue.
      const vivid = Oklch(0.5, 0.37, 264);
      final hex = toHex(vivid);
      expect(RegExp(r'^#[0-9a-f]{6}$').hasMatch(hex), isTrue);
      // The hue survives: the result is still blue, not purple.
      final back = fromHex(hex);
      // atan2 reports hue in (-180, 180]; wrap before comparing.
      final double h = back.h < 0 ? back.h + 360 : back.h;
      expect(h, closeTo(264, 6));
      expect(back.c, lessThan(vivid.c));
    });

    test('hex serialization round-trips within quantization', () {
      for (var h = 0; h < 360; h += 24) {
        final Oklch c = ramp(h.toDouble(), false, 0.5)['head']!;
        final back = fromHex(toHex(c));
        expect(back.l, closeTo(c.l, 0.01));
        expect(back.c, closeTo(c.c, 0.02));
        // Hue is circular: a hue quantized across the 0/360 boundary is the
        // same color, so compare the shorter way round the wheel.
        final double diff = (back.h - c.h).abs() % 360;
        expect(math.min(diff, 360 - diff), closeTo(0, 1.5));
      }
    });
  });

  group('blending', () {
    test('fadeHex travels in sRGB between the same endpoints', () {
      expect(fadeHex('#000000', '#ffffff', 0), '#000000');
      expect(fadeHex('#000000', '#ffffff', 1), '#ffffff');
      expect(fadeHex('#000000', '#ffffff', 0.5), '#808080');
      expect(fadeHex('#102030', '#102030', 0.7), '#102030');
    });

    test('mixHex lands on the OKLab walk, not the sRGB one', () {
      // At the endpoints the two agree; in between they must not.
      const a = '#ff0000';
      const b = '#00ff00';
      expect(mixHex(a, b, 0), a);
      expect(mixHex(a, b, 1), b);
      final oklabMid = mixHex(a, b, 0.5);
      expect(oklabMid, isNot(fadeHex(a, b, 0.5)));
    });

    test('every tint target holds the eye/body floor along the whole walk', () {
      for (final (String name, Tint tint) in tints) {
        for (var h = 0; h < 360; h += 30) {
          for (final double tone in const <double>[
            0,
            0.1,
            0.2,
            0.35,
            0.5,
            0.61,
            0.8,
            0.93,
            0.999
          ]) {
            final p = palette(h.toDouble(), true, tone);
            final (String hotHead, String hotEye) =
                tinted(p['head']!, p['eye']!, tint);
            double worst = double.infinity;
            for (var i = 0; i <= 10; i++) {
              final double t = i / 10;
              worst = math.min(
                worst,
                contrast(
                  fromHex(mixHex(p['eye']!, hotEye, t)),
                  fromHex(mixHex(p['head']!, hotHead, t)),
                ),
              );
            }
            // The walk clears the authored floor minus the 8-bit margin.
            expect(worst, greaterThanOrEqualTo(4.5),
                reason: '$name h=$h t=$tone worst=$worst');
          }
        }
      }
    });
  });
}
