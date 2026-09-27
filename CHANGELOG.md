# Changelog

## 0.2.0

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
