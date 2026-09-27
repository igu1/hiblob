/// The [Hiblob] widget.
library;

import 'package:flutter/widgets.dart';

import 'package:hiblob/hiblob.dart' show HiblobOptions;

import 'painter.dart';

/// Displays a deterministic hiblob for a name.
///
/// The same name always produces the same avatar within the frozen gen-2
/// contract. The widget owns sizing, the repaint boundary, and semantics; the
/// options are forwarded to the core unchanged (no adapter-invented
/// defaults).
///
/// - [size], when given, pins the square edge; otherwise the widget expands
///   to its constraints and the renderer centers the 100-by-100 viewBox on
///   the largest square inside them.
/// - [options] mirrors the JavaScript static options: `background`, `hue`,
///   `tone`, `palette`, `traits`, `normalize`, `contrast`, and `expression`.
/// - [semanticLabel] backs `Semantics(image: true)`. When null the element
///   is left unlabeled, matching the library's `title`-optional behavior.
class Hiblob extends StatelessWidget {
  /// The public identity used to derive deterministic traits.
  final String name;

  /// The square edge in logical pixels, or null to fill the parent constraints.
  final double? size;

  /// Generation, palette, backdrop, trait, and expression options.
  final HiblobOptions options;

  /// The optional assistive-technology label for this image.
  final String? semanticLabel;

  /// Creates a static deterministic hiblob.
  const Hiblob({
    super.key,
    required this.name,
    this.size,
    this.options = const HiblobOptions(),
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final HiblobPainter painter = HiblobPainter(name: name, options: options);
    final Widget figure;
    final double? edge = size;
    if (edge != null) {
      figure = SizedBox.square(
          dimension: edge, child: CustomPaint(painter: painter));
    } else {
      figure = SizedBox.expand(child: CustomPaint(painter: painter));
    }
    return RepaintBoundary(
      child: Semantics(
        image: true,
        label: semanticLabel,
        child: figure,
      ),
    );
  }
}
