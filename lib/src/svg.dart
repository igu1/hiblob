/// SVG export: serialized blobs that render outside Flutter.
///
/// The pure geometry layer already serializes paths (`toPathData`); this file
/// composes them into a complete, standalone SVG with the resolved palette —
/// usable in servers, web pages, design tools, mail templates.
library;

import 'color.dart';
import 'layout.dart';
import 'options.dart';

/// Renders [resolved] as an SVG document string.
///
/// The view box is the same 100-by-100 the Flutter renderer maps from. Fill
/// layers (backdrop, body, mouth, accessories) emit filled paths; stroked
/// marks (line eyes and mouth) emit stroked paths with round caps and joins
/// so the output matches the default Flutter painter exactly — at any scale.
String svgOf(ResolvedHiblob resolved) {
  final buffer = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 100 100" width="100" height="100">');
  for (final step in drawStepsOf(resolved)) {
    final color = argbToHex(step.color);
    buffer.write('<path d="${step.path.toPathData()}"');
    if (step.path.stroke) {
      buffer.write(' fill="none" stroke="$color" '
          'stroke-width="${_num(step.path.strokeWidth)}" '
          'stroke-linecap="round" stroke-linejoin="round"');
    } else {
      buffer.write(' fill="$color"');
    }
    buffer.write('/>');
  }
  buffer.write('</svg>');
  return buffer.toString();
}

/// Convenience for [svgOf]: resolves [name] with [options] first.
String svgFromName(String name,
        {HiblobOptions options = const HiblobOptions()}) =>
    svgOf(resolve(name, options: options));

String _num(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';
