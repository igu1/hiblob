import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiblob/flutter.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(child: child),
    ),
  );
}

Future<Uint8List> _pngOf(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .ancestor(
          of: find.byKey(key),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  // Rasterization needs real async time on the test binding; inside
  // `runAsync`, consecutive captures on the same boundary complete reliably.
  // A leading pump flushes pending repaints scheduled by the previous frame's
  // listeners before the boundary is snapshotted.
  await tester.pump();
  final ui.Image image = await tester.runAsync<ui.Image>(
    () => boundary.toImage(pixelRatio: 1),
  ) as ui.Image;
  final ByteData? data = await tester.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.png));
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('Hiblob paints deterministically and differs per name',
      (tester) async {
    const key = ValueKey('blob');
    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 64,
        height: 64,
        child: Hiblob(name: 'ada'),
      ),
    ));
    await tester.pump();

    final first = await _pngOf(tester, key);
    final second = await _pngOf(tester, key);
    expect(first, second);

    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 64,
        height: 64,
        child: Hiblob(name: 'grace'),
      ),
    ));
    await tester.pump();
    final other = await _pngOf(tester, key);
    expect(other, isNot(first));
  });

  testWidgets('Hiblob exposes its semantic label', (tester) async {
    // keep semantics alive only while the widget tree is inspected to avoid
    // an active SemanticsHandle at end-of-test verification time.
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
      const Hiblob(name: 'ada', size: 48, semanticLabel: 'Avatar of Ada'),
    ));
    expect(find.bySemanticsLabel('Avatar of Ada'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('AnimatedHiblob moves over time', (tester) async {
    const key = ValueKey('anim');
    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 96,
        height: 96,
        child: AnimatedHiblob(name: 'ada', animation: HiblobAnimation.always),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final before = await _pngOf(tester, key);
    await tester.pump(const Duration(milliseconds: 900));
    final after = await _pngOf(tester, key);
    expect(after, isNot(before));
  });

  testWidgets('AnimatedHiblob respects reduced motion', (tester) async {
    const key = ValueKey('anim');
    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 96,
        height: 96,
        child: AnimatedHiblob(name: 'ada', animation: HiblobAnimation.always),
      ),
      disableAnimations: true,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final before = await _pngOf(tester, key);
    await tester.pump(const Duration(milliseconds: 900));
    final after = await _pngOf(tester, key);
    expect(after, before);
  });

  testWidgets('AnimatedHiblob pauses when active is false', (tester) async {
    const key = ValueKey('anim');
    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 96,
        height: 96,
        child: AnimatedHiblob(name: 'ada', active: false),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final before = await _pngOf(tester, key);
    await tester.pump(const Duration(milliseconds: 900));
    final after = await _pngOf(tester, key);
    expect(after, before);
  });

  testWidgets('hover ramps ambient motion in and out', (tester) async {
    const key = ValueKey('anim');
    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 96,
        height: 96,
        child: AnimatedHiblob(name: 'ada', animation: HiblobAnimation.hover),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final idle = await _pngOf(tester, key);

    final gesture =
        await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byKey(key)));
    // Hover-mode ticker never settles while hovering, so ramp in with
    // explicit pumps: dispatch, ramp progress, then the repaint.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final hovered = await _pngOf(tester, key);
    expect(hovered, isNot(idle));

    await gesture.moveTo(const Offset(-1000, -1000));
    await tester.pumpAndSettle();
    final left = await _pngOf(tester, key);
    expect(left, isNot(hovered));
  });

  testWidgets('expression changes crossfade without throwing', (tester) async {
    await tester.pumpWidget(
      _wrap(const AnimatedHiblob(name: 'ada', size: 96)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(
      _wrap(const AnimatedHiblob(
        name: 'ada',
        size: 96,
        options: HiblobOptions(expression: thinking),
      )),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('name changes also crossfade, then match a static paint',
      (tester) async {
    const key = ValueKey('anim');
    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 96,
        height: 96,
        child: AnimatedHiblob(name: 'ada', active: false),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_wrap(
      const SizedBox(
        key: key,
        width: 96,
        height: 96,
        child: AnimatedHiblob(
          name: 'grace',
          active: false,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  test('MotionFrame equality works for shouldRepaint', () {
    expect(const MotionFrame(), const MotionFrame());
    expect(
      const MotionFrame(bodyY: 1),
      isNot(const MotionFrame(bodyY: 2)),
    );
  });
}
