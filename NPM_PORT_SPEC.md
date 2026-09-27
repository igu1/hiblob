# hiblob → npm: Complete Port Specification

> **You are building `@hiblob/core` (TypeScript/JavaScript) for npm.** It is a
> faithful, dependency-free port of the Dart package
> [`hiblob`](https://pub.dev/packages/hiblob) (MIT): deterministic geometric
> blob avatars from any string, with a zero-dependency core that emits a
> standalone SVG string. Follow this document exactly — every constant,
> band table, and formula below is transcribed from the shipped Dart source,
> so outputs stay visually identical to the Dart/Flutter version.

---

## 1. Product contract

- Input: any string (username, email, display name).
- Output: a fully resolved figure — or directly, an SVG string.
- **Determinism**: the same normalized input produces byte-identical output on
  every platform and every JS engine. All hashing is 32-bit integer math
  (`Math.imul`, `>>>`), all layout floats are plain IEEE 754 doubles.
- No network, no assets, no dependencies. ESM + CJS dual build, TypeScript
  types included, `package.json` exports both.

### Public API (target)

```ts
import {
  traitsFor,            // (name, options?) => Record<TraitKey, number>
  resolve,              // (name, options?) => ResolvedHiblob
  layoutFor,            // (name, options?) => DrawStep[]  (paint order)
  partsFor,             // (name, options?) => GeometryPath[] (body only)
  drawStepsOf,          // (resolved) => DrawStep[]
  svgOf,                // (resolved) => string  (standalone SVG document)
  svgFromName,          // (name, options?) => string
  motionSeedsFor,       // (name, options?) => MotionSeeds
  motionAt,             // (seeds, elapsedMs, ramp?) => MotionFrame
  normalizeSeed,        // (name) => string
  shapeBands, toneBands, traitKeys,
  expressions,          // idle, happy, sad, mad, surprised, wink, sleepy,
                        // smug, unsure, scared, love, shy, sick, thinking,
                        // grin, frown
  tintFor,              // (expression) => ARGB int
  AccessoryKeys,        // glasses, fringe, blush, antennae + defaultProbabilities
  HiblobOptions,        // class/const object with the fields below
  argbToHex, hexToArgb, hslToArgb, blendArgb, relativeLuminance,
  argbToOklch, oklchToArgb, oklchBlend,
  circle, ellipse, superellipse, roundedPolygon, roundedRect, radialBlob,
  star, droplet, halfDisc, polyline, quad, smoothClosed, rotatePt,
} from '@hiblob/core';
```

### `HiblobOptions`

```ts
interface HiblobOptions {
  background?: 'none' | 'squircle' | 'circle' | 'square'; // default 'none'
  hue?: number;              // degrees 0..360, pins color hue
  tone?: number;             // 0 <= v < 1, pins lightness band
  palette?: Record<'bg'|'head'|'eye', string>; // hex pins, last word wins
  accessories?: Record<'glasses'|'fringe'|'blush'|'antennae', number>;
                             // >=0.5 forces on, <0.5 forces off; omitted = name-driven
  mouth?: boolean;           // default true
  traits?: Record<string, number>; // pins, clamped to [0,1], unknown keys ignored
  normalize?: boolean;       // default true
  contrast?: boolean;        // default true
  expression?: Expression;   // default idle
}
```

Options are compared by value (all fields); equality is used by the motion
layer to detect expression/name changes.

---

## 2. File layout

```
src/
  hash.ts          // fnv1a32 + mulberry32 + stream(seed, key)
  normalize.ts     // normalizeSeed (NFC, trim, lowercase)
  traits.ts        // traitKeys, traitsFor, bandFor, shapeBands, toneBands
  color.ts         // hslToArgb, blendArgb, luminance, hex round-trip, OKLCh
  geometry.ts      // command types, GeometryPath, builders, toPathData
  expressions.ts   // Expression, 16 consts, roster, tintFor
  options.ts       // HiblobOptions, Backdrop, PaletteKeys, AccessoryKeys
  layout.ts        // resolve(), ResolvedHiblob, EyeGroup, Mouth, Accessory,
                   // DrawStep, layoutFor, partsFor, drawStepsOf
  motion.ts        // MotionSeeds, MotionFrame, motionAt, motionSeedsFor
  svg.ts           // svgOf, svgFromName
test/              // port of the Dart test suite (see §12)
```

---

## 3. Hashing (exact — do not simplify)

```ts
// 32-bit FNV-1a over UTF-8 bytes.
function fnv1a32(s: string): number {
  let h = 0x811c9dc5;
  for (const b of new TextEncoder().encode(s)) {
    h = Math.imul(h ^ b, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

// mulberry32 PRNG with a fixed portable sequence.
class Mulberry32 {
  private state: number;
  constructor(state: number) { this.state = state >>> 0; }
  next(): number {                       // returns [0, 1)
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ ((t + Math.imul(t ^ (t >>> 7), t | 61)) >>> 0)) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
}

// Key-addressed stream: one value per (seed, key) pair.
function stream(seed: string, key: string): number {
  return new Mulberry32((fnv1a32(seed) ^ fnv1a32(key)) >>> 0).next();
}
```

Key-addressing (hash of the key XORed with the hash of the seed, then one
draw) is the heart of the contract: adding new trait keys later never moves
existing traits, and any single trait can be pinned without disturbing the
others.

---

## 4. Normalization

```ts
function normalizeSeed(name: string): string {
  return name.trim().toLowerCase().normalize('NFC');
}
```

(README order in the Dart source says NFC, trim, lowercase; the Dart
implementation is `nfc(trim+lower)`. Either composition is acceptable — the
Dart package does `unorm.nfc(name.trim().toLowerCase())`, so keep that order:
trim → lowercase → NFC.)

---

## 5. Traits

```ts
const traitKeys = [
  'shape', 'hue', 'tone',
  'body.r', 'body.aspect',
  'eye.ratio', 'eye.spacing', 'eye.offset', 'face.offset', 'mouth',
  'detail.a', 'detail.b', 'detail.c', 'detail.phase',
  'nub.angle',
] as const;

function traitsFor(name: string, options?: HiblobOptions) {
  const seed = options?.normalize === false ? name : normalizeSeed(name);
  const traits: Record<string, number> = {};
  for (const k of traitKeys) traits[k] = stream(seed, k);
  for (const [k, v] of Object.entries(options?.traits ?? {})) {
    if (k in traits) traits[k] = clamp(v, 0, 1);
  }
  if (options?.hue != null) traits['hue'] = wrapDegrees(options.hue) / 360;
  if (options?.tone != null) traits['tone'] = clamp(options.tone, 0, 0.999999);
  return traits;
}
```

### Band tables (frozen visual contract)

```ts
const shapeBands: Record<string, [number, number]> = {
  round:    [0.000, 0.200],
  organic:  [0.200, 0.420],
  boxy:     [0.420, 0.550],
  nub:      [0.550, 0.650],
  capsule:  [0.650, 0.740],
  hexagon:  [0.740, 0.800],
  triangle: [0.800, 0.860],
  droplet:  [0.860, 0.905],
  cloud:    [0.905, 0.945],
  gem:      [0.945, 0.960],
  pillow:   [0.960, 0.972],
  sun:      [0.972, 1.010],
};

const toneBands: Record<string, [number, number]> = {
  pale: [0.00, 0.20], soft: [0.20, 0.40], mid: [0.40, 0.60],
  deep: [0.60, 0.80], ink:  [0.80, 1.01],
};
```

`bandFor(value, bands)`: first entry where `start <= value < end`; the final
band also catches `value == 1.0` (fall through to the last key otherwise).

---

## 6. Color math

Colors are carried as 32-bit ARGB ints throughout (`0xFFRRGGBB`).

```ts
// HSL → ARGB. h wraps, s/l clamp to [0,1].
function hslToArgb(hDeg: number, s: number, l: number): number { /* standard */ }

// sRGB linearization: v <= 0.04045 ? v/12.92 : ((v+0.055)/1.055)^2.4
function relativeLuminance(argb: number): number {
  // 0.2126*R + 0.7152*G + 0.0722*B over linearized channels
}

// Channel-lerp blend (kept for completeness; tints use OKLCh blend).
function blendArgb(from: number, to: number, t: number): number { /* standard */ }

// Hex helpers: '#RGB', '#RRGGBB', '#AARRGGBB', with/without '#'.
function hexToArgb(hex: string): number;
function argbToHex(argb: number): string; // '#RRGGBB', or '#AARRGGBB' if a < FF
```

### OKLCh (sRGB → linear sRGB → OKLab → OKLCh, and back)

Forward constants (linear sRGB components `r,g,b` → LMS, cube-root, OKLab):

```ts
const M1 = [
  [0.4122214705, 0.5363325363, 0.0514459929],
  [0.2119034982, 0.6806995451, 0.1073969566],
  [0.0883024619, 0.2817188376, 0.6299787005],
];
const M2 = [
  [ 0.2104542553,  0.7936177850, -0.0040720468],
  [ 1.9779984951, -2.4285922050,  0.4505937099],
  [ 0.0259040371,  0.7827717662, -0.8086757660],
];
// l' = cbrt(M1 row · rgb); L = M2[0]·lms'(with l',m',s'); a, b likewise.
// c = hypot(a, b); h = c == 0 ? 0 : atan2(b, a) in degrees wrapped to [0,360).
```

Inverse constants (OKLCh → OKLab → LMS³ → linear sRGB):

```ts
const M3 = [
  [1,  0.3963377774,  0.2158037573],
  [1, -0.1055613458, -0.0638541728],
  [1, -0.0894841775, -1.2914855480],
]; // l' = l + k0*a' + k1*b' per row; then CUBE each row's result.

const M4 = [                       // LMS³ → linear sRGB
  [ 4.0767416621, -3.3077115913,  0.2309699292],
  [-1.2684380046,  2.6097574011, -0.3413193965],
  [-0.0041960863, -0.7034186147,  1.7076147010],
];
// Gamma-encode: v <= 0.0031308 ? 12.92*v : 1.055*v^(1/2.4) - 0.055, *255, round, clamp.
```

> ⚠️ Precision notes from the Dart port: the **cube is applied to the M3 row
> result**; `Math.pow(x, 3)` on negative linear-sRGB values must be plain
> `x*x*x` (avoid domain errors). Round-trip `oklchToArgb(argbToOklch(c))`
> must land within ±2/255 per channel.

`oklchBlend(from, to, t)`: convert both to OKLCh, lerp L and C, lerp hue
along the **shortest arc** (`dh = wrap(b.h - a.h)`; if `dh > 180` subtract 360,
if `< -180` add 360), convert back. Expression tints use this, not
`blendArgb`.

---

## 7. Geometry

A `GeometryPath` is `{ commands: Cmd[], stroke?: boolean, strokeWidth?: number }`
with commands `MoveTo(x,y) | LineTo(x,y) | CubicTo(c1x,c1y,c2x,c2y,x,y) |
QuadraticTo(cx,cy,x,y) | ClosePath`. Coordinates are doubles in a
**100×100 view box**.

`toPathData()` serializes compactly, coords rounded to **2 decimals**
(`toFixed(2)`, no separator cleanup needed):

```
M12.34 56.78  L…  C c1x c1y c2x c2y x y  Q cx cy x y  Z
```

Equality = `toPathData() + stroke + strokeWidth`. Bounds = conservative box
over every endpoint and control point.

Builder constants and formulas (all angles in radians):

- `K = 0.5522847498307936` — circle→cubic handle constant.
- `circle(cx,cy,r) = ellipse(cx,cy,r,r)`.
- `ellipse(cx,cy,rx,ry)`: 4 cubics around center starting at `M(cx+rx, cy)`,
  using `rx*K`/`ry*K` handles, `Z`.
- `smoothClosed(pts[>=3])`: Catmull-Rom → cubic. For each i:
  `C1 = P1 + (P2 − P0)/6`, `C2 = P2 − (P3 − P1)/6` (indices mod n,
  starting at `M P0`), then `Z`.
- `superellipse(cx,cy,rx,ry,n,{samples=48})`: `e = 2/n`; for each t:
  `x = rx·sign(cos t)·|cos t|^e`, `y = ry·sign(sin t)·|sin t|^e`; then
  `smoothClosed`.
- `radialBlob(cx,cy,baseR,waves,{samples=32})`: `r = baseR + Σ wave.amp·baseR·
  cos(wave.harmonic·t + wave.phase)`; then `smoothClosed`.
- `roundedPolygon(cx,cy,radius,sides,rounding,{rotation=0})` (rounding
  clamped to [0, 0.5]): vertices at `rotation + 2πi/sides`; for each vertex,
  cut length `cut = min(|prev−cur|, |cur−next|) · rounding`; entry point
  `cur − dir(prev→cur)·cut`, exit `cur + dir(cur→next)·cut`;
  path `M starts[0]`, then per i: `Q verts[i] ends[i]`, `L starts[i+1]`, `Z`.
- `roundedRect(cx,cy,w,h,r)` with `r = min(r, min(w,h)/2)`: start
  `M(l+r, t)`, lines + 4 cubics with `k = r*K` in the standard order, `Z`.
  (A capsule when `r = min(w,h)/2`.)
- `star(cx,cy,outerR,innerR,points,{rotation=0})`: alternating
  `i % 2 == 0 ? outerR : innerR` at `rotation + πi/points`; `smoothClosed`.
- `droplet(cx,cy,bulbR,dropLen)`: tip at `(cx, cy − bulbR − dropLen)`,
  `bend = bulbR*0.62`; cubic down the left side to `(cx−bulbR, cy)`, arc the
  bulb bottom with `K` handles, cubic back up the right side to the tip, `Z`.
- `halfDisc(x,y,r,{down=true})`: `M(x−r, y)`, two cubics bulging
  `dir = down ? +1 : −1` with `K`, `Z` (filled semicircle).
- `polyline(pts, width=1.7)`: `M p0`, `L…` — **stroked**, round caps/joins.
- `quad(a,b,c,d)`: filled closed 4-gon.
- `rotatePt(x,y,cx,cy,angle)`: `cx + dx·cos − dy·sin, cy + dx·sin + dy·cos`.

---

## 8. Expressions

```ts
class Expression {
  constructor(
    public id: string,
    public eyeOffsetDx = 0, public eyeOffsetDy = 0,
    public tint?: number, public tintAlpha = 0,
  ) {}   // equality by id
}
```

Roster (16) and tints (`tintFor(id)`):

| id | offsets | tint | tintAlpha |
| --- | --- | --- | --- |
| idle | — | — | — |
| happy | — | — | — |
| sad | — | — | — |
| mad | — | `0xFFEF5350` | 0.10 |
| surprised | — | — | — |
| wink | — | — | — |
| sleepy | — | — | — |
| smug | — | — | — |
| unsure | — | — | — |
| scared | — | `0xFF90CAF9` | 0.10 |
| love | — | `0xFFF06292` | 0.22 |
| shy | — | `0xFFF8BBD0` | 0.15 |
| sick | — | `0xFF9CCC65` | 0.18 |
| thinking | dx −1.2, dy −1.6 | — | — |
| grin | — | — | — |
| frown | — | — | — |

---

## 9. Layout (`resolve`)

Constants: `viewBoxSize = 100`; body center `(cx, cy) = (50, 52)`.

```
resolve(name, options):
  traits      = traitsFor(name, options)
  seed        = normalize ? normalizeSeed(name) : name
  shape       = bandFor(traits.shape, shapeBands)
  toneBand    = bandFor(traits.tone, toneBands)
  hue         = traits.hue * 360
  (backdrop, backdropColor) = backdropFor(options, hue, toneBand)
  body        = bodyFor(shape, traits)
  (eyes, eyeColor, headColor) = faceFor(shape, traits, options, hue, toneBand)
  mouth       = options.mouth ? mouthFor(shape, traits, expression, eyes) : null
  accessories = accessoriesFor(shape, name, options, traits, eyes, headColor, eyeColor)
  return ResolvedHiblob { name, seed, options, traits, shape, hue, toneBand,
                          backdrop, backdropColor, body, headColor, eyes,
                          eyeColor, mouth, accessories }
```

### 9.1 Backdrop

`none` → null. Colors: `palette.bg` pin wins, else
`hslToArgb(hue, 0.55, tone === 'pale' ? 0.95 : 0.93)`. Plates:
`squircle → superellipse(50, 50, 48, 48, 4)`, `circle → circle(50,50,48)`,
`square → roundedRect(50, 50, 96, 96, 6)`.

### 9.2 Body (`bodyFor`)

`r = 26 + traits['body.r'] * 8` (i.e. 26–34).

| shape | path |
| --- | --- |
| round | `circle(50, 52, r)` |
| organic | `radialBlob(50, 52, r*1.02, [RadialWave(3, 0.020+0.050·a, p), RadialWave(5, 0.012+0.045·b, p*2.7+1.3), RadialWave(7, 0.008+0.028·c, p*4.1+2.9)])` where `a,b,c = detail.a/b/c`, `p = detail.phase · 2π` |
| boxy | `superellipse(50, 52, r*1.06, r*1.06, 3.4)` |
| nub | `circle(50, 52, r*0.94)` + `circle(50+d·cos(ang), 52+d·sin(ang), r*0.34)` with `d = r*0.82`, `ang = −π/2 + (nub.angle − 0.5)·2.4` |
| capsule | `roundedRect(50, 52, w, h, min(w,h)/2)`; vertical if `body.aspect < 0.5`: else `w = r*2.24, h = r*1.60` |
| hexagon | `roundedPolygon(50, 52, r*1.06, 6, 0.18, rotation: π/6)` |
| triangle | `roundedPolygon(50, 52, r*1.18, 3, 0.20, rotation: −π/2)` |
| droplet | `droplet(50, 52 + r*0.16, r*0.86, r*0.86*0.72)` |
| cloud | `circle(50, 52+r*0.18, r*0.82)` + `circle(50−r*0.62, 52+r*0.05, r*0.42)` + `circle(50+r*0.62, 52+r*0.08, r*0.40)` + `circle(50, 52−r*0.32, r*0.48)` |
| sun | `star(50, 52, r*1.16, r*0.74, 8, rotation: π/8)` |
| gem | `roundedPolygon(50, 52, r*1.10, 5, 0.12, rotation: −π/2)` |
| pillow | `superellipse(50, 52, r*1.10, r*0.92, 2.2)` |

### 9.3 Face

```
r  = 26 + traits['body.r'] * 8
rx = 3.1 − 1.0 · traits['eye.ratio']
ry = min(rx * (1 + 2.4 · traits['eye.ratio']), 9.5)
fy = 52 + traits['face.offset'] * 2.0 + faceDy(shape, r)
eyeY = clamp(fy + traits['eye.offset'] * 2.2 + expression.eyeOffsetDy,
             52 − r*0.42, 52 + r*0.38)
spread = max(5.2 + 4.6 · traits['eye.spacing'],
             rx * 2.6)                        // eyes never fuse
spread = min(spread, (halfWidthAtFace(shape, r, traits) − rx − 1.5) * 0.90)
leftEye  = eyeAt(50 − spread + expression.eyeOffsetDx, eyeY, left=true)
rightEye = eyeAt(50 + spread + expression.eyeOffsetDx, eyeY, left=false)
```

`halfWidthAtFace(shape, r, traits)` (conservative silhouette half-extent at
the eye line): round `r`; organic `r*1.02*1.10`; boxy `r*1.06`; nub
`r*0.94`; capsule horizontal `r*0.80` / vertical `r*1.12` (vertical when
`body.aspect < 0.5`); hexagon `r*0.98`; triangle `r*0.90`; droplet
`r*0.86*0.95`; cloud `r*0.82`; sun `r*0.74`; gem `r*0.95`; pillow `r*1.10`.

`faceDy`: round/organic/capsule/sun `0`; boxy `−1.5`; nub `0.5`; hexagon
`−1.0`; triangle `2.5`; droplet `r*0.16 + 1.5`; cloud `0.5`; gem `1.0`;
pillow `−1.0`.

`EyeGroup = { marks: GeometryPath[], strokeOnly: boolean, cx, cy }`.

Eye marks per expression id (`x` = eye center y-adjusted, `rx`, `ry`,
`left`):

| id | marks |
| --- | --- |
| idle | filled `ellipse(x, y, rx, ry)` |
| happy | filled `halfDisc(x, y + ry*0.15, rx*1.15, down=true)` |
| sad | filled `halfDisc(x, y + ry*0.2, rx*1.05, down=false)` |
| mad | filled `quad` of 4 points rotated around `(x,y)` by `(left ? +0.24 : −0.24)`: corners `(±rx*1.15, ±ry*0.55)` |
| surprised | filled `ellipse(x, y, rx*1.20, rx*1.30)` |
| wink | left: ellipse; right: `polyline[(x−rx*0.9,y) → (x+rx*0.9,y)]`, strokeOnly |
| sleepy | filled `halfDisc(x, y, rx*1.10, down=true)` |
| smug | left: `ellipse(x, y, rx*0.95, ry)`; right: `polyline[(x−rx*0.8, y+0.7) → (x+rx*0.9, y−1.0)]`, strokeOnly |
| unsure | left: `ellipse(x, y, rx, ry)`; right: `ellipse(x, y+0.8, rx*0.65, ry*0.65)` |
| scared | filled `ellipse(x, y, rx*1.30, ry*1.15)` |
| love | filled: `circle(x−rx*0.55, y−ry*0.18, rx*0.62)`, `circle(x+rx*0.55, …)`, `quad[(x, y+ry*0.80), (x−rx*1.02, y−ry*0.32), (x+rx*1.02, y−ry*0.32), (x, y+ry*0.80)]` |
| shy | filled `halfDisc(x, y, rx*0.95, down=true)` |
| sick | strokeOnly `polyline[(x−rx*0.85, y+(left?0.7:−0.7)), (x+rx*0.85, y−(left?0.7:−0.7)*0.7)]` |
| thinking | left: `ellipse(x, y, rx*0.95, ry*0.95)`; right: strokeOnly `polyline[(x−rx*0.85,y) → (x+rx*0.85,y)]` |
| grin | filled `ellipse(x, y, rx*1.05, ry)` |
| frown | filled `ellipse(x, y, rx, ry*0.9)` |

### 9.3.1 Mouth

`mouthY = min(avgEyeCy + 4.6 + 1.8·traits.mouth, 52 + r*0.55)`;
`mouthX = 50 + expression.eyeOffsetDx * 0.25`;
`half = min(2.5 + 3.6·traits.mouth, halfWidthAtFace·0.72)`;
`depth = 2.2 + 3.0·traits.mouth`.
Colors: mouth uses `eyeColor`.

- `_smile(x, y, half, depth)`: filled lens —
  `M(x−half, y)`, `C(x−half*0.35, y+depth, x+half*0.35, y+depth, x+half, y)`, `Z`
  (negative depth = frown).
- happy `_smile(x,y,half,depth*0.9)` · grin `_smile(x, y, half*1.15, depth*1.25)`
  · sad `_smile(x, y, half*0.9, −depth*0.7)` · frown `_smile(x, y, half, −depth)`
  · love `_smile(x, y, half*1.15*0.8?)` → use `half*1.15, depth*0.8`.
- surprised/scared/sleepy: filled ellipse variants (scared
  `half*0.62 × half*0.75`, surprised `half*0.55 × half*0.62` at `y+0.5`,
  sleepy `half*0.45 × half*0.5` at `y+0.6`).
- shy: strokeOnly `polyline[(x−half*0.6, y+0.9) → (x+half*0.6, y−0.2)]`, w 1.5.
- unsure: `polyline` `[(x−half*0.62, y+0.5) → (x+half*0.62, y+0.9)]`, w 1.6.
- sick: 5-point zigzag `polyline[(x−half,y), (x−half*0.5,y−1.2), (x,y+0.6),
  (x+half*0.5,y−1.2), (x+half,y)]`, w 1.5.
- smug: `polyline[(x−half*0.7, y−0.5) → (x+half*0.75, y+1.2)]`, w 1.6.
- mad: `polyline[(x−half*0.7, y+1.1) → (x+half*0.7, y−0.9)]`, w 1.6.
- thinking: `polyline[(x−half*0.55+dx*0.2, y−0.6) → (x+half*0.55+dx*0.2, y−1.0)]`, w 1.5.
- idle (default): `_smile(x, y, half*0.85, depth*0.5)`.

### 9.4 Palette

```
(s0, l0) = toneBase(toneBand): pale (0.42,0.88) soft (0.55,0.78)
             mid (0.60,0.66) deep (0.55,0.50) ink (0.30,0.24)
sJ = clamp(s0 + (detail.b − 0.5)*0.10, 0.05, 0.95)
lJ = clamp(l0 + (detail.c − 0.5)*0.08, 0.05, 0.95)
head  = hslToArgb(hue, sJ, lJ)
eye   = luminance(head) > 0.30 ? hslToArgb(hue, 0.45, 0.13)
                               : hslToArgb(hue, 0.30, 0.96)
if contrast and |lh − le| < 0.32:
    eye  = lh > 0.30 ? hslToArgb(hue, 0.45, 0.06) : hslToArgb(hue, 0.30, 0.99)
    le   = luminance(eye)
    if still < 0.32: head is nudged ±0.10 lightness (toward brighter when pale)
tint  = tintFor(expression)
if tint && tintAlpha > 0: head = oklchBlend(head, tint, tintAlpha)
palette pins: palette.head → head, palette.eye → eye (last word)
```

### 9.5 Accessories

Presence per key: pin from `options.accessories` (`>= 0.5` on) else
`stream(seed, 'accessory.<key>') < defaultProbabilities[key]`:
`glasses 0.30`, `fringe 0.40`, `blush 0.30`, `antennae 0.12`.

Colors: `accent = eyeColor`;
`fringeColor = luminance(head) > 0.30 ? oklchBlend(head, 0xFF20242E, 0.55)
                                      : oklchBlend(head, 0xFFF2F2F2, 0.35)`;
`blushColor = oklchBlend(head, 0xFFF4A9BE, 0.65)`;
`bandColor = oklchBlend(fringeColor, accent, 0.3)`;
`seamColor = oklchBlend(fringeColor, headColor, 0.28)`.

**Glasses** (`eyes.length === 2`):

```
lensWidth  = min(10.8, eyes[1].cx − eyes[0].cx − 2.4)
rr         = lensWidth / 2
ey         = (eyes[0].cy + eyes[1].cy) / 2
lensHeight = max(11, 2·(3.1 − eye.ratio)·(1 + 2.4·eye.ratio) + 3)
per eye:  roundedRect(eye.cx, ey, lensWidth, lensHeight, lensHeight/2 + 0.6)
          stroked 1.8, accent
bridge:   M(eyes[0].cx + rr, ey − 1.4) Q(midX, ey − 4.4, eyes[1].cx − rr, ey − 1.4)
          stroked 1.8
temple arms (per side s = −1 | +1):
          M(eye.cx + s·(rr − 0.4), ey − 1.0)
          Q(eye.cx + s·(rr + 2), ey − 2.6, eye.cx + s·(rr + 5), ey − 2.6)
          stroked 1.5, accent — **clipped to body[0]**
```

**Brow cap (`fringe`)** — fitted, clipped per body volume, in this order:

```
edgeY     = 52 − r*0.38
crownClip = roundedRect(50, edgeY/2, 100, edgeY, 0)   // everything above edgeY
bandClip  = roundedRect(50, edgeY − 1.8, 100, 3.6, 0) // a 3.6-tall cuff strip
for each body part:
  → Accessory(part, fringeColor, clip: crownClip)     // the cap itself
for each body part:
  → Accessory(part, bandColor, clip: bandClip)         // the cuff seam line
for each body part × side s ∈ {−1, +1}:
  → seam path  M(50 + s*3, 52 − r*0.78) Q(50 + s*6, 52 − r*0.65,
                 50 + s*7, edgeY − 4.5), stroked 0.7, seamColor,
              clip: part                                // panel stitching
```

The cap draws the **body paths themselves** re-colored and clipped to the
crown region — that is what makes it hug cloud puffs, nubs, and star points.
A generic circular dome overflows; never do that.

**Blush**: at `ey = eyes[0].cy`, `dx = max(|eyes[1].cx − eyes[0].cx|, 8)/2 + 2.2`,
blush radius `max(eyeSpread*0.30, 2.6)`; two filled circles at
`(50 ± dx, ey + 3.2)`, color `blushColor`, `underEyes: true`.

**Antennae**: `tipY = 52 − r − 4.5`; per side:
stroked polyline `(x: 50 + s*2.2, y: 52 − r*0.95) → (x: 50 + s*3.4 + (s>0?2:−2), y: tipY)`,
w 1.3 + filled `circle(tip, 1.6)`, accent.

Paint order (constrained by `ResolvedHiblob`):
`backdrop → body → mouth → under-eye accessories (blush) → eyes →
above-face accessories (cap, glasses, antennae)`.

---

## 10. Motion

```ts
interface MotionSeeds {
  bobPhase, bobPeriod,           // phase ∈ [0,2π), period 2.4–3.6 s
  breathePhase, breathePeriod,   // period 3.0–4.5 s
  blinkPeriod, blinkOffset,      // period 2.8–5.5 s, offset 0–0.35 of period
  glancePeriod, glanceSeed,      // period 1.8–3.8 s
  seesawPhase, tremorPhase,      // phases ∈ [0,2π)
  expression: Expression,        // held loops read this
}

motionSeedsFor(name, options?)
  seed = normalize ? normalizeSeed(name) : name
  bobPhase     = stream(seed, 'motion.bob.phase')     * 2π
  bobPeriod    = 2.4  + stream(seed, 'motion.bob.period')    * 1.2
  breathePhase = stream(seed, 'motion.breathe.phase') * 2π
  breathePeriod= 3.0  + stream(seed, 'motion.breathe.period')  * 1.5
  blinkPeriod  = 2.8  + stream(seed, 'motion.blink.period')    * 2.7
  blinkOffset  = stream(seed, 'motion.blink.offset') * 0.35
  glancePeriod = 1.8  + stream(seed, 'motion.glance.period')   * 2.0
  glanceSeed   = stream(seed, 'motion.glance.seed')
  seesawPhase  = stream(seed, 'motion.seesaw.phase')  * 2π
  tremorPhase  = stream(seed, 'motion.tremor.phase')  * 2π
  expression   = options?.expression ?? idle

interface MotionFrame {   // view-box units
  bodyX, bodyY,           // offsets (right/down positive)
  bodyScaleY,             // 1 ± ~1.2%
  blink,                  // 0..1, 1 fully closed
  gazeX, gazeY,           // eye offsets −1.8..1.8 each axis
}

motionAt(seeds, elapsedMs, ramp = 0):
  t = elapsedMs / 1000
  ambient = 0.35 + 0.65 · clamp(ramp, 0, 1)
  bob     = sin(2π·t/bobPeriod + bobPhase) · 1.5 · ambient
  bodyY   = bob − 2.0·ramp
  bodyX = 0; tremor = 0
  if expression.id === 'thinking':
      bodyX = sin(2π·t/6.0 + seesawPhase) · 1.1 · ambient       // slow seesaw
  else if expression.id === 'mad':
      tremor = (sin(2π·t/0.32 + tremorPhase)·0.8
              + sin(2π·t/0.21 + tremorPhase·1.7)·0.4) · ambient  // fast tremor
      bodyX   = sin(2π·t/0.53 + tremorPhase)·0.35·ambient
  bodyScaleY = 1 + sin(2π·t/breathePeriod + breathePhase)·0.012·ambient
  bt    = ((t + blinkOffset·blinkPeriod) mod blinkPeriod) / blinkPeriod
  blink = (0.55 <= bt <= 0.605) ? sin((bt − 0.55)/0.055·π) : 0
  // Glances: target changes each glancePeriod; ease-out over first 12%.
  index = floor(t / glancePeriod); frac = t/glancePeriod − index
  ease  = frac < 0.12 ? easeOutCubic(frac/0.12) : 1   // 1 − (1−u)³
  glance(axis): (prev + (cur − prev)·ease) · 1.8 · ambient
      where cur/prev = rand(seed 'glance/<glanceSeed>/<index>' hashed, axis)
      — in TS: stream(`glance/${glanceSeed}/${index}`, axis) · 2 − 1
  return { bodyX, bodyY: bodyY + tremor, bodyScaleY, blink,
           gazeX: glance('x'), gazeY: glance('y') }
```

Frame guarantees: at `elapsed = 0` the frame is always blink-free; motion is
continuous frame to frame; ramp 0 quiets ambient motion to 35%.

---

## 11. SVG emission (`svgOf`)

```ts
function svgOf(resolved: ResolvedHiblob): string {
  let out = '<svg xmlns="http://www.w3.org/2000/svg" '
          + 'viewBox="0 0 100 100" width="100" height="100">';
  let clipIndex = 0;
  for (const step of drawStepsOf(resolved)) {
    let clipPrefix = '', clipSuffix = '';
    if (step.clip) {
      const id = `cap-clip-${clipIndex++}`;
      clipPrefix = `<defs><clipPath id="${id}" clipPathUnits="userSpaceOnUse">`
                 + `<path d="${step.clip.toPathData()}"/></clipPath></defs>`
                 + `<g clip-path="url(#${id})">`;
      clipSuffix = '</g>';
    }
    out += clipPrefix + '<path d="' + step.path.toPathData() + '"';
    const color = argbToHex(step.color);
    if (step.path.stroke) {
      out += ` fill="none" stroke="${color}"`
           + ` stroke-width="${fmt(step.path.strokeWidth)}"`
           + ' stroke-linecap="round" stroke-linejoin="round"';
    } else {
      out += ` fill="${color}"`;
    }
    out += '/>' + clipSuffix;
  }
  return out + '</svg>';
}
```

Example fragment from an actual resolved figure (name `'ada@example.com'`,
round shape, squircle backdrop, glasses + cap):

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <path d="M2.00 50.00C2.00 24.11 ..." fill="#F1D9EA"/>
  <path d="M77.09 56.02C77.09 71.20 64.79 ..." fill="#C4667C"/>
  <path d="M54.72 63.27C48.99 62.44 ..." fill="#88344D"/>
  <defs><clipPath id="cap-clip-0" clipPathUnits="userSpaceOnUse">
    <path d="M0.00 41.12L100.00 41.12L100.00 0.00L0.00 0.00Z"/></clipPath></defs>
  <g clip-path="url(#cap-clip-0)">
    <path d="M77.09 56.02C77.09 71.20 ..." fill="#A24B5F"/>
  </g>
  <path d="M67.04 55.70C67.04 59.48 64.09 62.55 60.46 ..." fill="none"
        stroke="#3D1F33" stroke-width="1.8" stroke-linecap="round"/>
</svg>
```

---

## 12. Renderer parity notes (for any canvas binding)

If you also want a canvas renderer (optional for npm v1):

- Map the 100×100 view box onto the largest centered square in the target
  size: `side = min(w, h)`, translate `(size − side)/2`, scale `side/100`.
- Draw order per §9.5. Body/mouth/accessories move together:
  `translate(bodyX, bodyY)` → `translate(50, 52)` → `scale(1, bodyScaleY)` →
  `translate(−50, −52)`; then eyes with `translate(gazeX, gazeY)` and blink
  scaling each open eye vertically around its own `(cx, cy)` by
  `1 − blink` (`strokeOnly` eyes never blink).
- Clip steps use `ctx.clip()` with the clip's `Path2D`.
- Fill steps: `fill()`. Stroke steps: `stroke()` with
  `lineCap = lineJoin = 'round'`.

---

## 13. Tests to port (from the Dart suite)

1. `traitsFor`: deterministic per name; differs across names; normalization
   (`'  ADA '`, decomposed `'e' + U+0301` ≡ `'é'`); pins clamp/wrap; unknown
   pins ignored; NFC on both sides.
2. Band tables: every band reachable across ≥4000 names; documented edge
   values (0.0 round, 0.2 organic, 0.945 gem, 0.96 pillow, 0.972 sun, 1.0
   sun); everyday shapes stay everyday (`round` + `organic` ≥ 55% of draws),
   loud shapes rare (`sun < 8%`).
3. `resolve`: deterministic; two eyes left→right in every figure; eyes never
   fuse; every silhouette keeps its geometry inside the view box; all 16
   expressions resolve for every shape; wink has exactly one strokeOnly eye.
4. Mouths: present by default (bounds inside the box), differs per
   expression, `mouth: false` removes it.
5. Accessories: deterministic presence; pins force on/off; the fitted cap
   covers the body's upper region — **for every (shape, body.r) pair, every
   point inside the body above `edgeY` is covered by at least one cap path ∩
   clip**; accessories stay inside the view box (antennae may overhang to
   `y ≥ −6`).
6. OKLCh: round-trip within ±2/255 per channel for key colors
   (`#DD4422`, `#101010`, `#F2F2F2`, `#00AABB`); gray has ~zero chroma;
   endpoints of `oklchBlend` within ±3/255.
7. `layoutFor`/`partsFor`/`drawStepsOf`: draw list covers exactly backdrop +
   body + mouth + under/over accessories + eyes in paint order.
8. SVG: starts with the xmlns viewBox prolog, ends `</svg>`; contains head +
   backdrop hex; `fill="none" stroke=` present for stroke marks; clipPath
   markup present when a cap is on; count of `<path d` ≥ body.length + 2.
9. Motion: deterministic; differs per name; starts blink-free; blinks
   somewhere within 2 periods; stays in bounds; continuous; ramp quiets;
   `thinking` seesaw reaches |bodyX| > 0.7; `mad` tremor shifts `bodyY` by
   > 0.5 vs idle; held loops survive ramp 0 at 35% but stay quieter than
   ramp 1.
10. Snapshot golden: `svgFromName('ada@example.com', { background: 'squircle',
    expression: happy })` — store the exact string; any code change that
    changes it is a breaking visual-contract change.

Use `vitest` (or `node:test`); keep everything synchronous, no async in the
hot path.

## 14. Package setup

```jsonc
// package.json
{
  "name": "@hiblob/core",
  "version": "1.0.0",
  "license": "MIT",
  "type": "module",
  "exports": {
    ".": { "types": "./dist/index.d.ts", "import": "./dist/index.js",
           "require": "./dist/index.cjs" }
  },
  "files": ["dist", "README.md", "LICENSE"],
  "scripts": { "build": "tsup src/index.ts --format esm,cjs --dts",
               "test": "vitest run" },
  "engines": { "node": ">=18" }
}
```

- `index.ts` re-exports the public API from §1.
- `README.md`: short pitch, install (`npm i @hiblob/core`), API table, SVG
  sample, link back to the Dart/Flutter package. MIT LICENSE file.
- Validate: `npx publint` must be clean before `npm publish`.

## 15. Determinism pitfalls in JS (read before coding)

- Use `Math.imul` for every 32-bit multiply, `>>> 0` after each round of
  mixed ops — never let a hash value exceed 2³¹−1 into JS bitwise ops.
- `TextEncoder().encode` for UTF-8 in `fnv1a32` (matches Dart's
  `utf8.encode`).
- `String.prototype.normalize('NFC')` (Node ≥ 10.17 has full ICU; fine).
- Keep coordinate rounding identical (`toPathData` at 2 decimals) so SVG
  output matches the Dart exporter byte-for-byte.
- Never use `Math.random()` anywhere. Never accept `Date.now()` inside the
  layout pipeline; motion takes elapsed time as an explicit argument.
```
