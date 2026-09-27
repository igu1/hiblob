/// The pure static renderer for a hiblob.
///
/// Resolves one seed's layout and palette once, then paints the
/// figure onto a `Canvas` through `dart:ui` primitives — never through a
/// rasterized or wrapped SVG. This is the object the widget and every Flutter
/// consumer share; it exposes none of the core's internal geometry structs,
/// so callers depend only on [name], the options, and the paint result.
library;

import 'dart:ui' as ui;

import 'package:hiblob/hiblob.dart' as core;

import '../shape.dart' show BlobPath;
import 'path.dart';

/// A resolved, ready-to-draw hiblob.
///
/// [paint] maps the 100-by-100 viewBox onto the largest centered square inside
/// [size], so a widget can hand this any constraints without distortion. The
/// paint is deterministic: the same seed and options always produce the same
/// geometry and palette, so two paints of the same renderer are pixel
/// identical (modulo antialiasing, which is engine-level and reproduces
/// deterministically on the same device).
class HiblobRenderer {
  /// The name resolved into this renderer's cached geometry.
  final String name;

  /// The immutable core options resolved with [name].
  final core.HiblobOptions options;

  late final core.HiblobLayout _layout;
  late final List<core.Petal> _petals;
  late final List<BlobPath> _extra;
  late final List<ui.Path> _eyes;
  late final ui.Path? _backdrop;
  late final ui.Color? _backdropColor;
  late final ui.Color _head;
  late final ui.Color _eye;

  /// Resolves [name] with [options] immediately (the same normalization,
  /// hashing, and contrast the deterministic core guarantees).
  HiblobRenderer(
      {required this.name, this.options = const core.HiblobOptions()}) {
    _resolve();
  }

  void _resolve() {
    final (core.HiblobLayout l, core.Palette palette) =
        core.partsFor(name, options);
    _layout = l;
    _petals = l.petals;
    _extra = l.extra;
    _eyes = [for (final BlobPath p in l.eyePaths()) toUiPath(p)];
    _head = colorFromHex(palette[core.colorHead]!);
    _eye = colorFromHex(palette[core.colorEye]!);
    final core.BackdropGeometry? bg = core.backdropFor(
      options.background,
      palette,
      styleDefault: core.Backdrop.none,
    );
    _backdrop = bg == null ? null : toUiPath(bg.path);
    _backdropColor = bg == null ? null : colorFromHex(bg.fill);
  }

  /// Whether a backdrop plate is drawn (the `background` option).
  bool get hasBackdrop => _backdrop != null;

  /// Paints the figure onto [canvas], mapping the 100-by-100 viewBox onto the
  /// largest square centered in [size]. Draw order matches the reference
  /// renderer: backdrop, petals, extra outlines, core body, then eyes.
  void paint(ui.Canvas canvas, ui.Size size) {
    final double side = size.width < size.height ? size.width : size.height;
    if (side <= 0) return;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    _paintViewed(canvas);
    canvas.restore();
  }

  void _paintViewed(ui.Canvas canvas) {
    final ui.Path? backdrop = _backdrop;
    if (backdrop != null) {
      canvas.drawPath(backdrop, _fillPaint(_backdropColor!));
    }
    canvas.save();
    canvas.translate(0, _layout.bodyOffsetY);
    final ui.Paint headPaint = _fillPaint(_head);
    final ui.Paint eyePaint = _fillPaint(_eye);
    for (final core.Petal p in _petals) {
      canvas.drawPath(
        ui.Path()
          ..addOval(
              ui.Rect.fromCircle(center: ui.Offset(p.cx, p.cy), radius: p.r)),
        headPaint,
      );
    }
    for (final BlobPath extra in _extra) {
      canvas.drawPath(toUiPath(extra), headPaint);
    }
    canvas.drawPath(toUiPath(_layout.bodyPath()), headPaint);
    for (final ui.Path eyePath in _eyes) {
      canvas.drawPath(eyePath, eyePaint);
    }
    canvas.restore();
  }

  ui.Paint _fillPaint(ui.Color color) => ui.Paint()
    ..color = color
    ..style = ui.PaintingStyle.fill;
}
