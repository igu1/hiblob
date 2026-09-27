import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hiblob/hiblob.dart' as core;
import 'package:hiblob/flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('always mode advances seeded ambient motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AnimatedHiblob(
            name: 'alain',
            size: 100,
            animation: HiblobAnimation.always,
          ),
        ),
      ),
    );
    final AnimatedHiblobPainter painter = _painter(tester);
    final AnimatedHiblobFrame first = painter.currentFrame;
    expect(first.amplitude, 1);

    await tester.pump(const Duration(milliseconds: 137));
    final AnimatedHiblobFrame next = _painter(tester).currentFrame;
    expect(next.motion.breathe, isNot(first.motion.breathe));
    expect(next.motion.bob, isNot(first.motion.bob));
  });

  testWidgets('hover mode ramps in and out with pointer interaction',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AnimatedHiblob(name: 'ada', size: 100),
        ),
      ),
    );
    expect(_painter(tester).currentFrame.amplitude, 0);

    final TestGesture mouse =
        await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is AnimatedHiblobPainter,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).currentFrame.amplitude, closeTo(1, 1e-6));
    expect(_painter(tester).currentFrame.hover, closeTo(1, 1e-6));

    await mouse.moveTo(const ui.Offset(1, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).currentFrame.amplitude, closeTo(0, 1e-6));
    expect(_painter(tester).currentFrame.hover, closeTo(0, 1e-6));
    await mouse.removePointer();
  });

  testWidgets('expression changes morph and preserve interruption continuity',
      (tester) async {
    final GlobalKey<_HarnessState> key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(MaterialApp(home: _Harness(key: key)));

    final AnimatedHiblobRenderer renderer = _painter(tester).renderer;
    key.currentState!.setExpression(core.happy);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final AnimatedHiblobFrame halfwayFrame = _painter(tester).currentFrame;
    final double progress = core.expressionEnterEase(0.5);
    final core.Pose halfway = halfwayFrame.pose;
    _expectPoseClose(
      halfway,
      core.lerpPose(core.idle.pose, core.happy.pose, progress),
    );
    final core.Palette idlePalette = renderer.paletteFor(core.idle);
    final core.Palette happyPalette = renderer.paletteFor(core.happy);
    expect(
      halfwayFrame.headColor,
      _uiColor(
        core.fadeHex(
          idlePalette[core.colorHead]!,
          happyPalette[core.colorHead]!,
          progress,
        ),
      ),
    );
    expect(
      halfwayFrame.eyeColor,
      _uiColor(
        core.fadeHex(
          idlePalette[core.colorEye]!,
          happyPalette[core.colorEye]!,
          progress,
        ),
      ),
    );
    expect(_painter(tester).renderer, same(renderer));

    key.currentState!.setExpression(core.sad);
    await tester.pump();
    final AnimatedHiblobFrame interrupted = _painter(tester).currentFrame;
    _expectPoseClose(interrupted.pose, halfway);
    expect(interrupted.headColor, halfwayFrame.headColor);
    expect(interrupted.eyeColor, halfwayFrame.eyeColor);

    await tester.pump(const Duration(milliseconds: 300));
    expect(_painter(tester).currentFrame.pose, core.sad.pose);

    key.currentState!.setExpression(core.idle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).currentFrame.pose, core.identityPose);
  });

  testWidgets('unrelated rebuilds reuse the resolved renderer', (tester) async {
    final GlobalKey<_HarnessState> key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(MaterialApp(home: _Harness(key: key)));
    final AnimatedHiblobRenderer before = _painter(tester).renderer;

    key.currentState!.changeLabel();
    await tester.pump();
    expect(_painter(tester).renderer, same(before));

    key.currentState!.changeName();
    await tester.pump();
    expect(_painter(tester).renderer, isNot(same(before)));
  });

  testWidgets('reduced motion and inactive widgets use the static path',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AnimatedHiblob(
            name: 'alain',
            size: 80,
            animation: HiblobAnimation.always,
            options: core.HiblobOptions(expression: core.thinking),
          ),
        ),
      ),
    );
    expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is HiblobPainter,
        ),
        findsOneWidget);
    expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is AnimatedHiblobPainter,
        ),
        findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnimatedHiblob(
          name: 'alain',
          size: 80,
          active: false,
          animation: HiblobAnimation.always,
        ),
      ),
    );
    expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is HiblobPainter,
        ),
        findsOneWidget);
  });

  testWidgets('TickerMode pauses callbacks and disposal removes them',
      (tester) async {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.instance;
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: AnimatedHiblob(
            name: 'alain',
            size: 80,
            animation: HiblobAnimation.always,
          ),
        ),
      ),
    );
    expect(binding.transientCallbackCount, 0);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnimatedHiblob(
          name: 'alain',
          size: 80,
          animation: HiblobAnimation.always,
        ),
      ),
    );
    expect(binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}

AnimatedHiblobPainter _painter(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is CustomPaint && widget.painter is AnimatedHiblobPainter,
    ),
  );
  return paint.painter! as AnimatedHiblobPainter;
}

ui.Color _uiColor(String hex) => ui.Color(
      int.parse(hex.substring(1), radix: 16) | 0xff000000,
    );

void _expectPoseClose(core.Pose actual, core.Pose expected) {
  final Map<String, double> a = actual.toJson();
  final Map<String, double> b = expected.toJson();
  for (final String key in a.keys) {
    expect(a[key], closeTo(b[key]!, 1e-9), reason: key);
  }
}

class _Harness extends StatefulWidget {
  const _Harness({super.key});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String name = 'alain';
  String label = 'Alain';
  core.Expression expression = core.idle;

  void setExpression(core.Expression value) =>
      setState(() => expression = value);

  void changeLabel() => setState(() => label = 'Avatar of Alain');

  void changeName() => setState(() => name = 'ada');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedHiblob(
        name: name,
        size: 100,
        semanticLabel: label,
        animation: HiblobAnimation.always,
        options: core.HiblobOptions(expression: expression),
      ),
    );
  }
}
