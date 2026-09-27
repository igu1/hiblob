/// Option resolution and the renderer seam.
///
/// Deterministic option resolution: the path from a name and
/// [HiblobOptions] to resolved layout and palette. Pose and elapsed-time
/// motion stay in their own modules.
library;

import 'color.dart';
import 'expression.dart';
import 'shape.dart';
import 'traits.dart';
import 'styles/blob.dart' show style;
import 'styles/compose.dart';

/// How the backdrop is drawn. Mirrors the JS option values
/// `false | "square" | "circle" | "squircle"`.
///
/// The JS option also accepts `true`, which renders the squircle plate
/// (`n: 6`); use [Backdrop.squircle] for that case.
enum Backdrop { none, square, circle, squircle }

/// The options the layout and palette resolution read.
///
/// Expressions are resolved by both static and animated renderers.
class HiblobOptions {
  /// Overrides specific palette entries. Overridden colors bypass the
  /// contrast guarantee.
  final Map<String, String>? palette;

  /// Locks the hue in degrees, so the name drives shape only.
  final double? hue;

  /// Locks the tone as a 0-1 position in the swatch set, pale to ink.
  ///
  /// The swatches are banded with half-open edges, so an exact `1` sits on the
  /// top edge rather than under it and falls back to the first swatch: `1`
  /// renders what `0` renders. Reach for ink with `0.999`.
  final double? tone;

  /// Pins individual traits, so the name drives only what you leave out.
  ///
  /// Each value is the 0-1 position the hash would have produced for that
  /// key — the same units the layout reads. Values outside [0, 1) are
  /// clamped.
  final Map<String, Object>? traits;

  /// Applies NFC + trim + lowercase to the name. Default true.
  final bool normalize;

  /// Enforces the minimum contrast ratios. Default true.
  final bool contrast;

  /// The backdrop the renderer draws behind the figure. Default: the style's
  /// own, which for gen-2 is none.
  final Backdrop? background;

  /// The static pose to apply. Omitted and [idle] are equivalent.
  final Expression? expression;

  const HiblobOptions({
    this.palette,
    this.hue,
    this.tone,
    this.traits,
    this.normalize = true,
    this.contrast = true,
    this.background,
    this.expression,
  });

  /// Value equality: two option sets render the same avatar iff they are
  /// equal. Maps compare by their entries (values may be a number or a list
  /// of numbers), so a `RepaintBoundary`/`shouldRepaint` decision never
  /// repaints for an unrelated property change.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HiblobOptions) return false;
    return normalize == other.normalize &&
        contrast == other.contrast &&
        hue == other.hue &&
        tone == other.tone &&
        background == other.background &&
        expression == other.expression &&
        _mapEquals(palette, other.palette, _scalarEquals) &&
        _mapEquals(traits, other.traits, _scalarEquals);
  }

  @override
  int get hashCode => Object.hash(
        normalize,
        contrast,
        hue,
        tone,
        background,
        expression,
        Object.hashAllUnordered(palette?.entries ?? const []),
        Object.hashAllUnordered(traits?.entries ?? const []),
      );
}

bool _scalarEquals(Object? a, Object? b) {
  if (a == b) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  return false;
}

/// Compares two maps by [valueEquals] on each key's values (order agnostic,
/// like the pure-Dart core).
bool _mapEquals(Map<Object?, Object?>? a, Map<Object?, Object?>? b,
    bool Function(Object?, Object?) valueEquals) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final MapEntry<Object?, Object?> entry in a.entries) {
    final Object? other = b[entry.key];
    if (!valueEquals(entry.value, other)) return false;
  }
  return true;
}

/// The resolved inputs: the trait reader and the final palette.
class Resolved {
  final Traits t;
  final Palette palette;
  const Resolved(this.t, this.palette);
}

/// Normalizes and hashes the name once, builds the trait reader, and resolves
/// the palette — including the `hue`/`tone` friendly units and the palette
/// overrides. `hue`/`tone` win over `traits` entries for the same two traits.
Resolved resolve(String seed, [HiblobOptions opts = const HiblobOptions()]) {
  final Traits t = traitsFor(
    seed,
    normalize: opts.normalize,
    overrides: opts.traits,
  );
  final Map<String, String> p = palette(
    opts.hue ?? t.numIn('hue', 0, 360),
    opts.contrast,
    opts.tone ?? t('tone'),
  );
  if (opts.palette != null) {
    p.addAll(opts.palette!);
  }
  return Resolved(t, p);
}

/// The plate behind the figure, as geometry rather than as markup.
class BackdropGeometry {
  final BlobPath path;
  final String fill;
  const BackdropGeometry(this.path, this.fill);
}

/// The backdrop is the style's concern to default, not the renderer's.
BackdropGeometry? backdropFor(Backdrop? background, Palette p,
    {Backdrop styleDefault = Backdrop.none}) {
  final Backdrop bg = background ?? styleDefault;
  switch (bg) {
    case Backdrop.none:
      return null;
    case Backdrop.square:
      // `M0 0H100V100H0Z` — box(50, 50, 50, 50) emits exactly this.
      return BackdropGeometry(box(50, 50, 50, 50), p[colorBg]!);
    case Backdrop.circle:
      return BackdropGeometry(
        superellipse(const Superellipse(cx: 50, cy: 50, rx: 50, ry: 50, n: 2)),
        p[colorBg]!,
      );
    case Backdrop.squircle:
      return BackdropGeometry(
        superellipse(const Superellipse(cx: 50, cy: 50, rx: 50, ry: 50, n: 6)),
        p[colorBg]!,
      );
  }
}

/// The hiblob in the pieces a renderer needs.
///
/// The resolved layout of one seed (without the pose half, which is a
/// later phase): the resolved palette next to the full numeric layout, so
/// color assertions can read the same numbers a renderer paints.
HiblobLayout layoutFor(String name,
    [HiblobOptions opts = const HiblobOptions()]) {
  final Resolved r = resolve(name, opts);
  final HiblobLayout layout = style.layout(r.t);
  return opts.expression == null
      ? layout
      : bakePose(layout, opts.expression!.pose);
}

/// Layout and palette together, for renderers that own the drawing.
(HiblobLayout, Palette) partsFor(String name,
    [HiblobOptions opts = const HiblobOptions()]) {
  final Resolved r = resolve(name, opts);
  final Expression? expression = opts.expression;
  final HiblobLayout layout = style.layout(r.t);
  if (expression == null) return (layout, r.palette);
  return (
    bakePose(layout, expression.pose),
    expressionPalette(r.palette, expression),
  );
}
