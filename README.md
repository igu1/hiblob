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
| `traits` | `Map<String, Object>` | Pins trait positions; omitted traits remain name-driven. |
| `normalize` | `bool` | Applies NFC, trim, and lowercase when true. |
| `contrast` | `bool` | Enforces the contrast floors when true. |
| `expression` | `Expression` | Applies one of the fourteen poses and optional tint. |

All expression values are exported from either library: `idle`, `happy`,
`sad`, `mad`, `surprised`, `wink`, `sleepy`, `smug`, `unsure`, `scared`,
`love`, `shy`, `sick`, and `thinking`.

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
final layout = layoutFor('ada@example.com');
final colors = ramp(210);
final frame = motionAt(
  motionSeedsFor('ada@example.com'),
  1200,
  1,
);
```

- `traitsFor` exposes the deterministic trait reader.
- `layoutFor`, `partsFor`, and `resolve` expose resolved output.
- `ramp` and `palette` expose the authored OKLCh palette pipeline.
- `superellipse`, `blobPath`, and `polygon` expose structured path primitives.
- `motionSeedsFor` and `motionAt` expose deterministic motion without a
  Flutter controller.

## The visual contract

A hiblob's seed-to-look mapping is frozen: ten silhouettes, the OKLCh tone
set, fourteen expressions, and every numeric range the layout reads a trait
into move together, and adding to any of them is a breaking change by
definition. The same name always renders the same figure.

`test/fixtures/reference-vectors.json` is a checked-in, self-describing
fixture with 1,570 layout cases, 42 expression cases, every silhouette band,
normalization and non-ASCII inputs, palette/tone edges, and trait overrides.
The Dart tests read it; they never update it from implementation output, and
`test/` is excluded from the published package archive.

Dart VM trigonometric functions call the host C math library. IEEE 754 does
not require one bit-exact sin/cos implementation, so trig-derived layout
floats use the fixture's tight 1e-9 relative tolerance. Rounded path data,
hash values, traits, palette hex, and expression channels remain exact.

NFC is provided by `unorm_dart`. The fixture covers the normalization cases
that affect the paste-a-name contract.

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
hue, backdrop, and motion mode. It also demonstrates held expression loops, a
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
dart test test/dart
flutter test test/flutter
dart doc

cd example
flutter pub get
flutter analyze
flutter test
```

## License

MIT — see [LICENSE](LICENSE).
