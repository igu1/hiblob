import 'dart:math' as math;

import 'package:hiblob/hiblob.dart';
import 'package:test/test.dart';

import 'helpers.dart';

final Map<String, Expression> _byName = {
  for (final expression in expressions) expression.name: expression,
};

HiblobOptions _withExpression(
  Map<String, dynamic> json,
  Expression expression,
) {
  final base = optionsFromJson(json);
  return HiblobOptions(
    palette: base.palette,
    hue: base.hue,
    tone: base.tone,
    traits: base.traits,
    normalize: base.normalize,
    contrast: base.contrast,
    background: base.background,
    expression: expression,
  );
}

void main() {
  final expressionVectors = vectors['expressions'] as Map<String, dynamic>;

  test('exports the complete expression roster', () {
    expect(_byName.keys.toList(), expressionVectors.keys.toList());
    expect(expressions.length, 14);
  });

  test('every pose matches the reference channels exactly', () {
    for (final entry in expressionVectors.entries) {
      final expected =
          (entry.value as Map<String, dynamic>)['pose'] as Map<String, dynamic>;
      expect(_byName[entry.key]!.pose.toJson(), expected, reason: entry.key);
    }
  });

  test('static geometry and tint match all reference cases', () {
    for (final entry in expressionVectors.entries) {
      final expression = _byName[entry.key]!;
      final data = entry.value as Map<String, dynamic>;
      for (final raw in data['cases'] as List<dynamic>) {
        final expected = raw as Map<String, dynamic>;
        final options = _withExpression(
          expected['options'] as Map<String, dynamic>,
          expression,
        );
        final (layout, palette) = partsFor(expected['seed'] as String, options);
        expect(layout.shape, expected['shape'], reason: entry.key);
        expect(layout.bodyOffsetY, expression.pose.bdy, reason: entry.key);
        final eyes = expected['eyes'] as List<dynamic>;
        for (var i = 0; i < layout.eyes.length; i++) {
          expectEye(layout.eyes[i], eyes[i] as Map<String, dynamic>,
              '${entry.key}.eyes[$i]');
        }
        expect(palette, expected['palette'], reason: '${entry.key}.palette');
      }
    }
  });

  test('idle is identical to an omitted expression', () {
    for (var i = 0; i < 200; i++) {
      final seed = 'idle-$i';
      final (plainLayout, plainPalette) = partsFor(seed);
      final (idleLayout, idlePalette) =
          partsFor(seed, const HiblobOptions(expression: idle));
      expect(idleLayout.bodyPath().toPathData(),
          plainLayout.bodyPath().toPathData());
      expect(idleLayout.eyePaths().map((p) => p.toPathData()),
          plainLayout.eyePaths().map((p) => p.toPathData()));
      expect(idleLayout.bodyOffsetY, 0);
      expect(idlePalette, plainPalette);
    }
  });

  test('differential channels affect only the second eye', () {
    final base = layoutFor('seed-7');
    final posed = layoutFor(
      'seed-7',
      const HiblobOptions(expression: wink),
    );
    expect(posed.eyes[0].rx / base.eyes[0].rx, wink.pose.esx);
    expect(posed.eyes[1].rx / base.eyes[1].rx, wink.pose.esx + wink.pose.esx2);
    expect(posed.eyes[0].ry / base.eyes[0].ry, wink.pose.esy);
    expect(posed.eyes[1].ry / base.eyes[1].ry, wink.pose.esy + wink.pose.esy2);
  });

  test('posed eyes never fuse across a seed sweep', () {
    double reach(Eye eye) {
      final angle = eye.rot * math.pi / 180;
      return (eye.rx * math.cos(angle)).abs() +
          (eye.ry * math.sin(angle)).abs();
    }

    for (final expression in expressions) {
      for (var i = 0; i < 800; i++) {
        final layout = layoutFor(
          'expression-$i',
          HiblobOptions(expression: expression),
        );
        final left = layout.eyes[0];
        final right = layout.eyes[1];
        expect(
            (right.cx - left.cx).abs(), greaterThan(reach(left) + reach(right)),
            reason: '${expression.name} seed=$i');
      }
    }
  });

  test('tinting expressions retain eye-to-head contrast', () {
    for (final expression in expressions.where((e) => e.tint != null)) {
      for (var i = 0; i < 100; i++) {
        final (_, colors) = partsFor(
          'tint-$i',
          HiblobOptions(expression: expression),
        );
        expect(
          contrast(fromHex(colors[colorEye]!), fromHex(colors[colorHead]!)),
          greaterThanOrEqualTo(4.5),
          reason: '${expression.name} seed=$i',
        );
      }
    }
  });
}
