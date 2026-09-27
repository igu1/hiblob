# hiblob

Deterministic geometric blob avatars — **hiblobs** — from any string.

A hiblob always stands for somebody: a user, a bot, a team, a repo. Generate
it from that somebody's `name` — a username, a display name, an email, a
handle, an id. Any string works, and the same string always renders the same
hiblob, on every platform, forever.

- **No network, no assets.** The figure is computed from the name and painted
  directly with Flutter `Canvas` primitives. No web view, no wrapped SVG, no
  image files to bundle.
- **Pure Dart core.** Normalization, hashing, traits, the OKLCh palette
  pipeline, geometry, expressions, and elapsed-time motion import neither
  Flutter nor `dart:ui`, so you can render or compute anywhere Dart runs.
- **Static or animated.** Seeded breathe, bob, blink, and glance motion is
  opt-in, and expression changes morph between poses.
- **Expressive by default.** Mouths, deterministic accessories (glasses, a
  brow cap, blush, antennae), and held expression loops come built in — all
  name-driven, all pinnable.
- **Exits Flutter.** The resolved draw list can be emitted as a standalone
  SVG document for servers, mail, and design tools.

## Install

```sh
flutter pub add hiblob
```

The package exposes two libraries:

- `package:hiblob/hiblob.dart` contains the deterministic core: normalization,
  hashing, traits, palette, geometry, expressions, and elapsed-time motion. It
  imports neither Flutter nor `dart:ui`.
- `package:hiblob/flutter.dart` adds static and animated Flutter widgets,
  painters, and Canvas renderers, and re-exports the common core values.

Applications that only need calculations can import the core library without
pulling Flutter types into their source.

## Static widget

```dart
import 'package:hiblob/flutter.dart';

Hiblob(
  name: user.email,
  size: 64,
  semanticLabel: 'Avatar of ${user.displayName}',
  options: const HiblobOptions(
    background: Backdrop.squircle,
    expression: happy,
  ),
)
```

`size` pins a square edge. Without it, the widget expands to its constraints
and centers the 100-by-100 view box inside the largest square.
`semanticLabel` labels the image for assistive technology.

## Animated widget

```dart
AnimatedHiblob(
  name: user.email,
  size: 120,
  animation: HiblobAnimation.always,
  options: const HiblobOptions(expression: thinking),
)

AnimatedHiblob(
  name: user.email,
  animation: HiblobAnimation.hover,
)
```

`HiblobAnimation.always` runs seeded breathe, bob, blink, and saccade motion
continuously. `HiblobAnimation.hover` ramps ambient motion and lift in while
a pointer is over the widget; it stays idle in non-interacted lists.
Expression changes morph between poses with the library's own timing and
easing, including held `thinking` seesaw and `mad` tremor loops.

Set `active: false` when an application knows a widget is off-screen. The
widget also follows `TickerMode`, disposes every controller with its state,
and uses the static rendering path when `MediaQuery.disableAnimations`
requests reduced motion. Set `respectReducedMotion: false` only when the
application provides an equivalent accessibility control.

## Options

Options are immutable and forwarded to the core as-is:

```dart
HiblobOptions(
  background: Backdrop.circle,
  hue: 210,
  tone: 0.8,
  palette: const {'eye': '#ffffff'},
  traits: const {
    'shape': 0.99,
    'eye.ratio': 0,
  },
  normalize: true,
  contrast: true,
  expression: love,
)
```

| Option | Dart value | Behavior |
| --- | --- | --- |
| `background` | `Backdrop.none`, `.squircle`, `.circle`, `.square` | Draws the matching backdrop plate. |
| `hue` | degrees | Pins color while the name continues to drive other traits. |
| `tone` | `0 <= value < 1` | Selects an authored lightness/chroma band. |
| `palette` | `Map<String, String>` | Overrides selected bg, head, or eye colors. |
| `mouth` | `bool` | Draws the expression's mouth; set `false` for eyes only. |
| `accessories` | `Map<String, double>` | Pins accessories by `AccessoryKeys`; omitted keys stay name-driven. |
| `traits` | `Map<String, Object>` | Pins trait positions; omitted traits remain name-driven. |
| `normalize` | `bool` | Applies NFC, trim, and lowercase when true. |
| `contrast` | `bool` | Enforces the contrast floors when true. |
| `expression` | `Expression` | Applies one of the sixteen poses and optional tint. |

All expression values are exported from either library: `idle`, `happy`,
`sad`, `mad`, `surprised`, `wink`, `sleepy`, `smug`, `unsure`, `scared`,
`love`, `shy`, `sick`, `thinking`, `grin`, and `frown`.

### Accessories

Four accessories are drawn deterministically from the name when they are not
pinned: round glasses, a color-matched brow cap with a contrasting cuff,
under-eye blush discs, and antennae. Force any of them on or off:

```dart
// Glasses always on; blush and antennae always off; the cap stays
// name-driven.
Hiblob(
  name: user.email,
  options: const HiblobOptions(accessories: {
    AccessoryKeys.glasses: 1,
    AccessoryKeys.blush: 0,
    AccessoryKeys.antennae: 0,
  }),
);
```

The cap is fitted, not stamped: it covers the actual upper outline of the
silhouette — including cloud puffs, nubs, and star points — and finishes
with a cuff and stitched panel seams. Glasses ride the eye line with a
curved bridge and temple arms that end on the body outline.

### Configuring

`background`, `hue` and `tone` cover the common cases; `traits` pins any
individual axis to the 0–1 position the hash would otherwise have produced:

```dart
// Always a blue-ish plate; everything else still per name.
Hiblob(name: user.email, hue: 210, size: 48);

// Always a sun with wide eyes — colour and everything else still per name.
Hiblob(
  name: user.email,
  options: const HiblobOptions(traits: {'shape': 0.95, 'eye.ratio': 0}),
);
```

Keys you leave out still come from the name — lock the two things that carry
your brand, and every user still gets their own creature. Pin everything and
the name stops mattering, which is how you build one fixed hiblob.

## Core API

```dart
import 'package:hiblob/hiblob.dart';

final traits = traitsFor('ada@example.com');
final layout = layoutFor('ada@example.com'); // the paint-order draw list
final frame = motionAt(motionSeedsFor('ada@example.com'), 1200, ramp: 1);
final svg = svgFromName('ada@example.com');
```

- `traitsFor` exposes the deterministic trait reader.
- `resolve` returns a fully resolved figure; `layoutFor` flattens it into
  paint-order `DrawStep`s, `partsFor` returns the body paths, and
  `drawStepsOf` applies to an already resolved figure.
- `svgOf` and `svgFromName` emit standalone SVG documents.
- The palette pipeline is authored in HSL and blended in OKLCh;
  `argbToOklch`, `oklchToArgb`, and `oklchBlend` expose the perceptual
  color math, and `hexToArgb`/`argbToHex` round-trip pins.
- `superellipse`, `roundedPolygon`, `radialBlob`, and the rest of the
  geometry builders expose structured path primitives.
- `motionSeedsFor` and `motionAt` expose deterministic motion without a
  Flutter controller.

## The visual contract

A hiblob's seed-to-look mapping is frozen: twelve silhouettes, the tone set,
sixteen expressions, the accessory roster, and every numeric range the layout
reads a trait into move together, and changing any of them is a breaking
change by definition. The same name always renders the same figure.

`test/` is a repository artifact and is excluded from the published archive
via `.pubignore`. Determinism is pinned by the test suite: band edges,
normalization cases (composed, decomposed, trimmed, and cased input),
palette/tone edges, trait overrides, per-shape accessibility coverage for the
fitted cap, and SVG document structure.

NFC is provided by `unorm_dart`, so composed and decomposed spellings of a
name hash identically.

## Supported platforms

| Platform | Static | Animated | Notes |
| --- | --- | --- | --- |
| Android | Yes | Yes | Use `always` for touch-first ambient motion. |
| iOS | Yes | Yes | Use `always` for touch-first ambient motion. |
| Web | Yes | Yes | Supports both `hover` and `always`. |
| macOS | Yes | Yes | Supports both `hover` and `always`. |
| Windows | Yes | Yes | Supports both `hover` and `always`. |
| Linux | Yes | Yes | Supports both `hover` and `always`. |

The supported SDK floor is Dart 3.6 / Flutter 3.27.

## Example

`example/` is an interactive studio for changing the name, shape, expression,
hue, backdrop, mouth, accessories, and motion mode — with a **Copy SVG**
export. It also demonstrates held expression loops (`thinking`, `mad`), a
hover-animated gallery, and reduced continuous list work.

```sh
cd example
flutter pub get
flutter run -d chrome
```

## Development

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
dart analyze
flutter test
dart doc

cd example
flutter pub get
flutter analyze
flutter test
```

## License

MIT — see [LICENSE](LICENSE).
