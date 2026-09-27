import 'package:flutter/material.dart';

import 'package:hiblob/hiblob.dart' as core;

enum WebSeedMark {
  claude('Claude'),
  codex('Codex');

  final String label;

  const WebSeedMark(this.label);
}

const Map<String, WebSeedMark> _keys = {
  'b0d11833': WebSeedMark.claude,
  'd4cde064': WebSeedMark.codex,
  'e1fc8517': WebSeedMark.claude,
  'ede616c3': WebSeedMark.codex,
};

WebSeedMark? webSeedMarkFor(String name) => _keys[_key(name)];

String _key(String name) {
  final String normal =
      core.normalizeSeed(name).replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  int hash = 0x811c9dc5;
  for (final int codeUnit in normal.codeUnits) {
    hash = core.imul(hash ^ codeUnit, 0x01000193);
  }
  return (hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
}

class WebSeedMarkView extends StatelessWidget {
  final WebSeedMark mark;
  final double size;
  final String? semanticLabel;

  const WebSeedMarkView({
    super.key,
    required this.mark,
    required this.size,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        image: true,
        label: semanticLabel,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _WebSeedMarkPainter(mark)),
        ),
      ),
    );
  }
}

class _WebSeedMarkPainter extends CustomPainter {
  final WebSeedMark mark;

  const _WebSeedMarkPainter(this.mark);

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);
    switch (mark) {
      case WebSeedMark.claude:
        _paintClaude(canvas);
      case WebSeedMark.codex:
        _paintCodex(canvas);
    }
    canvas.restore();
  }

  void _paintClaude(Canvas canvas) {
    const List<String> pixels = [
      '..##########..',
      '..##########..',
      '..##.####.##..',
      '..##.####.##..',
      '.############.',
      '.############.',
      '..##########..',
      '..##########..',
      '...#.#..#.#...',
    ];
    const double cell = 90 / 14;
    const double originX = 5;
    final double originY = (100 - pixels.length * cell) / 2;
    final Path figure = Path();

    for (var row = 0; row < pixels.length; row++) {
      var start = -1;
      for (var column = 0; column <= pixels[row].length; column++) {
        final bool filled =
            column < pixels[row].length && pixels[row][column] == '#';
        if (filled && start < 0) start = column;
        if (!filled && start >= 0) {
          figure.addRect(
            Rect.fromLTWH(
              originX + start * cell,
              originY + row * cell,
              (column - start) * cell,
              cell,
            ),
          );
          start = -1;
        }
      }
    }

    canvas.drawPath(
      figure,
      Paint()
        ..color = const Color(0xffd97757)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintCodex(Canvas canvas) {
    const List<(double, double, double)> circles = [
      (50, 52, 30),
      (33, 33, 18),
      (58, 27, 20),
      (75, 42, 19),
      (74, 66, 18),
      (52, 77, 20),
      (29, 68, 18),
      (23, 49, 17),
    ];
    Path cloud = Path();
    for (final (double x, double y, double radius) in circles) {
      final Path lobe = Path()
        ..addOval(Rect.fromCircle(center: Offset(x, y), radius: radius));
      cloud = cloud.getBounds().isEmpty
          ? lobe
          : Path.combine(PathOperation.union, cloud, lobe);
    }

    canvas.save();
    canvas.clipPath(cloud);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffb3a4ff), Color(0xff7a00ff)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.restore();

    final Paint prompt = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(36, 34)
        ..lineTo(50, 50)
        ..lineTo(36, 66),
      prompt,
    );
    canvas.drawLine(const Offset(55, 64), const Offset(72, 64), prompt);
  }

  @override
  bool shouldRepaint(_WebSeedMarkPainter oldDelegate) =>
      mark != oldDelegate.mark;
}
