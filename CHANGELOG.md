# Changelog

## 1.0.1

- README visual refresh: hero and generated sample galleries embedded in the
  readme, plus samples in `assets/`.
- Expanded link to the official JavaScript port — `hiblob` on npm
  ([github.com/igu1/hiblob-npm](https://github.com/igu1/hiblob-npm)) — with
  byte-identical output, golden-tested against this implementation.
- New untracked spec: `NPM_PORT_SPEC.md`, the complete handoff document the
  npm port was built from. No visual or API changes.

## 1.0.0

First stable release. Deterministic geometric blob avatars from any string,
with a pure Dart core and static or animated Flutter widgets.

- Pure Dart core: NFC normalization, hashing, traits, HSL + OKLCh palette,
  geometry, expressions, and elapsed-time motion — no Flutter or `dart:ui`.
- Static and animated Flutter widgets with hover/always motion, expression
  crossfades, held `thinking` seesaw and `mad` tremor loops, reduced-motion
  support, and tickers that only run while motion should advance.
- Twelve silhouettes, sixteen expressions, four backdrops, and a fitted
  accessory layer (glasses with curved bridges, an outline-following brow cap
  with cuff and seams, blush, antennae) — all name-driven and pinnable.
- Mouths per expression, active or off via `HiblobOptions(mouth: false)`.
- SVG export (`svgOf`, `svgFromName`) and the `layoutFor`/`partsFor`/
  `drawStepsOf` draw list for use outside Flutter.

- Accessory redesign: the brow cap is now fitted to the actual upper outline
  of every silhouette (cloud puffs, nubs, and star points included) with a
  contrasting cuff and stitched panel seams, instead of a circular dome that
  overflowed wide or spiky shapes. Caps and seams are clipped to the body in
  both the Canvas renderer and SVG export.
- Glasses redesigned: wider rounded lenses, a curved bridge, and temple arms
  that end on the body outline instead of stubs floating mid-air.
- Mouths: every expression now draws a mouth under the eyes; turn it off with
  `HiblobOptions(mouth: false)`. Two new expressions, `grin` and `frown`.
- Accessories: a deterministic accessory layer (glasses, brow fringe, blush,
  antennae), name-driven by default and pinnable per key through
  `HiblobOptions.accessories` with `AccessoryKeys`.
- Two new silhouettes, `gem` and `pillow`, rebanding the rare tail
  (`droplet`, `cloud`, `sun` moved slightly — a 0.2.0 visual contract bump).
- OKLCh color helpers: `argbToOklch`, `oklchToArgb`, and `oklchBlend`.
  Expression tints now blend perceptually.
- Names now normalize through Unicode NFC (`unorm_dart`): `e` + U+0301 and
  `é` hash identically.
- Held expression motion: `thinking` slowly seesaws its body, `mad` adds a
  fast tremor — both arrive in `MotionFrame.bodyX`/`bodyY` and quiet with the
  ramp.
- `layoutFor`/`partsFor`/`drawStepsOf` expose the resolved draw list without
  Flutter.
- SVG export: `svgOf`/`svgFromName` produce standalone SVG documents.
- The face (body, mouth, accessories) now rides the bob/breathe transform
  together in the Flutter renderer.

## 0.1.0

- Initial release.
- Pure Dart core: deterministic normalization, hashing, traits, OKLCh colors,
  geometry, expressions, and elapsed-time motion — no Flutter or `dart:ui`
  imports.
- Static and animated Flutter painters and widgets with hover/always motion,
  expression morphing, reduced-motion support, and lifecycle-safe tickers.
- Ten silhouettes, fourteen expressions, four backdrops, and an authored
  OKLCh palette, all driven by a frozen seed-to-look mapping pinned by the
  checked-in reference fixture.
- Blob Studio example app, parity fixtures, and package CI checks.
