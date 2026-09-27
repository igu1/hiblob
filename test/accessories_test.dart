import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hiblob/flutter.dart';

void main() {
  test('cap covers the upper outline of every silhouette and body size', () {
    for (final band in shapeBands.entries) {
      for (final radius in [0.0, 0.5, 1.0]) {
        final figure = resolve('cap-fit',
            options: HiblobOptions(
              traits: {
                'shape': (band.value.$1 + band.value.$2) / 2,
                'body.r': radius,
              },
              accessories: const {
                AccessoryKeys.fringe: 1,
                AccessoryKeys.glasses: 0,
                AccessoryKeys.blush: 0,
                AccessoryKeys.antennae: 0,
              },
            ));
        final body = figure.body.map(uiPathFrom).toList();
        final cap = figure.accessories
            .where((a) => !a.path.stroke)
            .map((a) => (path: uiPathFrom(a.path), clip: uiPathFrom(a.clip!)))
            .toList();
        final edge = 52 - (26 + radius * 8) * 0.38;
        for (var y = 0.5; y < edge - 0.5; y += 1) {
          for (var x = 0.5; x < 100; x += 1) {
            final point = ui.Offset(x, y);
            final inBody = body.any((p) => p.contains(point));
            final inCap = cap
                .any((p) => p.path.contains(point) && p.clip.contains(point));
            expect(inCap, inBody,
                reason: '${band.key}, radius $radius, at $point');
          }
        }
        expect(svgOf(figure), contains('clipPathUnits="userSpaceOnUse"'));
      }
    }
  });
}
