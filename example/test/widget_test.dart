import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hiblob_example/main.dart';

void main() {
  testWidgets('Hiblob Studio builds and renders', (WidgetTester tester) async {
    await tester.pumpWidget(const HiblobStudioApp());
    // The studio shows its surface and at least one blob painter.
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
