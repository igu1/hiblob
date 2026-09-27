import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hiblob/hiblob.dart' as core;
import 'package:hiblob/flutter.dart';
import 'package:hiblob_example/main.dart';
import 'package:hiblob_example/web_seed_marks.dart';

void main() {
  test('web seed aliases resolve to their matching marks', () {
    expect(webSeedMarkFor(' Claude '), WebSeedMark.claude);
    expect(webSeedMarkFor('anthropic'), WebSeedMark.claude);
    expect(webSeedMarkFor('CODEX'), WebSeedMark.codex);
    expect(webSeedMarkFor('openai'), WebSeedMark.codex);
    expect(webSeedMarkFor('ada'), isNull);
  });

  testWidgets('seed, shape, and expression update the large preview', (
    WidgetTester tester,
  ) async {
    await _pumpStudio(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('seed-input')),
      'ada',
    );
    await tester.pump();

    AnimatedHiblob preview = tester.widget<AnimatedHiblob>(
      find.byKey(const ValueKey<String>('preview-hiblob')),
    );
    expect(preview.name, 'ada');
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('preview-surface')),
        matching: find.byType(Card),
      ),
      findsNothing,
    );

    await tester.tap(find.text('circle'));
    await tester.tap(find.byKey(const ValueKey<String>('hue-140')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('appearance-picker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey<String>('shape-triangle')));
    final Finder thinking = find.byKey(
      const ValueKey<String>('expression-thinking'),
    );
    await tester.ensureVisible(thinking);
    await tester.tap(thinking);
    await tester.tap(find.byKey(const ValueKey<String>('appearance-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    preview = tester.widget<AnimatedHiblob>(
      find.byKey(const ValueKey<String>('preview-hiblob')),
    );
    expect(preview.options.traits, <String, Object>{'shape': 0.99});
    expect(preview.options.expression, core.thinking);
    expect(preview.options.hue, 140);
    expect(preview.options.background, core.Backdrop.circle);
    expect(find.text('triangle · thinking'), findsNWidgets(2));
    expect(find.byType(AnimatedHiblob), findsNWidgets(15));
    for (int index = 0; index < 12; index++) {
      expect(
        find.byKey(ValueKey<String>('gallery-avatar-$index')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('thinking-motion-demo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mad-motion-demo')),
      findsOneWidget,
    );
  });

  testWidgets('motion controls update and pause the preview', (
    WidgetTester tester,
  ) async {
    await _pumpStudio(tester);

    AnimatedHiblob preview = tester.widget<AnimatedHiblob>(
      find.byKey(const ValueKey<String>('preview-hiblob')),
    );
    expect(preview.animation, HiblobAnimation.always);
    expect(preview.active, isTrue);

    await tester.tap(find.text('hover'));
    await tester.pump();
    preview = tester.widget<AnimatedHiblob>(
      find.byKey(const ValueKey<String>('preview-hiblob')),
    );
    expect(preview.animation, HiblobAnimation.hover);

    await tester.tap(
      find.byKey(const ValueKey<String>('motion-active-switch')),
    );
    await tester.pump();
    preview = tester.widget<AnimatedHiblob>(
      find.byKey(const ValueKey<String>('preview-hiblob')),
    );
    expect(preview.active, isFalse);
  });

  testWidgets('Claude and Codex presets replace and lock the preview', (
    WidgetTester tester,
  ) async {
    await _pumpStudio(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('seed-input')),
      'claude',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('preview-special-mark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('preview-hiblob')),
      findsNothing,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('appearance-picker')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<SegmentedButton<HiblobAnimation>>(
            find.byKey(const ValueKey<String>('motion-mode-picker')),
          )
          .onSelectionChanged,
      isNull,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey<String>('motion-active-switch')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<SegmentedButton<core.Backdrop>>(
            find.byKey(const ValueKey<String>('background-picker')),
          )
          .onSelectionChanged,
      isNull,
    );

    final Finder codexButton = find.byKey(const ValueKey<String>('use-codex'));
    await tester.ensureVisible(codexButton);
    await tester.tap(codexButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Codex web preset · locked'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey<String>('seed-input')))
          .controller!
          .text,
      'codex',
    );
  });
}

Future<void> _pumpStudio(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const HiblobExampleApp());
  await tester.pump();
}
