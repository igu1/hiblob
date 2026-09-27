import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hiblob/hiblob.dart' as core;
import 'package:hiblob/flutter.dart';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a name at a pinned size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Hiblob(name: 'alain', size: 48)),
      ),
    );
    final Finder figure = find.byWidgetPredicate(
      (Widget w) => w is CustomPaint && w.painter is HiblobPainter,
    );
    expect(figure, findsOneWidget);
    final Size layout = tester.getSize(figure);
    expect(layout.width, 48);
    expect(layout.height, 48);
  });

  testWidgets('repaints when name or options change and not otherwise',
      (tester) async {
    expect(binding, isNotNull);
    // Exercise the painter's shouldRepaint contract directly.
    final HiblobPainter a =
        HiblobPainter(name: 'alain', options: const core.HiblobOptions());
    final HiblobPainter same =
        HiblobPainter(name: 'alain', options: const core.HiblobOptions());
    final HiblobPainter otherName =
        HiblobPainter(name: 'bob', options: const core.HiblobOptions());
    final HiblobPainter otherHue = HiblobPainter(
        name: 'alain', options: const core.HiblobOptions(hue: 200));
    final HiblobPainter otherBg = HiblobPainter(
        name: 'alain',
        options: const core.HiblobOptions(background: core.Backdrop.square));

    expect(a.shouldRepaint(same), isFalse, reason: 'identical config');
    expect(a.shouldRepaint(otherName), isTrue, reason: 'name change');
    expect(a.shouldRepaint(otherHue), isTrue, reason: 'hue change');
    expect(a.shouldRepaint(otherBg), isTrue, reason: 'background change');
  });

  testWidgets('option forwarding reaches the renderer exactly', (tester) async {
    final core.HiblobOptions opts = core.HiblobOptions(
      hue: 210,
      tone: 0.5,
      normalize: false,
      traits: const {'shape': 0.99},
      background: core.Backdrop.squircle,
    );
    final HiblobPainter painter = HiblobPainter(name: 'alain', options: opts);
    expect(painter.renderer.options, same(opts));
    expect(painter.renderer.hasBackdrop, isTrue);
    // The renderer resolved the same options: the squircle backdrop must be
    // present (hasBackdrop) and the layout must reflect the pinned shape.
    final core.HiblobLayout layout = core.layoutFor('alain', opts);
    expect(layout.shape, 'triangle');
  });

  testWidgets('renders every static expression value', (tester) async {
    for (final core.Expression expression in core.expressions) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Hiblob(
              name: 'expression-${expression.name}',
              size: 48,
              options: core.HiblobOptions(expression: expression),
            ),
          ),
        ),
      );
      final CustomPaint paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is HiblobPainter,
        ),
      );
      final painter = paint.painter! as HiblobPainter;
      expect(painter.options.expression, expression, reason: expression.name);
    }
  });

  testWidgets('semantics: semanticLabel sets an image semantic',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child:
              Hiblob(name: 'alain', size: 32, semanticLabel: 'Avatar of Alain'),
        ),
      ),
    );
    final Finder sem = find.bySemanticsLabel('Avatar of Alain');
    expect(sem, findsOneWidget);
  });
}
