/// Deterministic elapsed-time motion for hiblobs.
///
/// This is the arithmetic counterpart of `motion.css`: every loop is a pure
/// function of the shared elapsed clock, per-seed timing, ambient amplitude,
/// and expression channels. Flutter adapters can therefore repaint from a
/// ticker without accumulating state or regenerating paths.
library;

import 'expression.dart';
import 'traits.dart';

/// Seeded periods, phases, and look direction for one hiblob.
class MotionSeeds {
  /// Breathing phase offset in milliseconds.
  final int phase;

  /// Bob phase offset in milliseconds.
  final int bob;

  /// Seeded blink period in milliseconds.
  final int blink;

  /// Blink phase offset in milliseconds.
  final int blinkPhase;

  /// Seeded saccade period in milliseconds.
  final int saccade;

  /// Saccade phase offset in milliseconds.
  final int saccadePhase;

  /// Signed horizontal look distance.
  final double lookX;

  /// Signed vertical look distance.
  final double lookY;

  /// Unsigned horizontal look distance used by eye wrapping.
  final double lookMagnitudeX;

  /// Unsigned vertical look distance used by eye wrapping.
  final double lookMagnitudeY;

  /// Creates a complete set of deterministic motion seeds.
  const MotionSeeds({
    required this.phase,
    required this.bob,
    required this.blink,
    required this.blinkPhase,
    required this.saccade,
    required this.saccadePhase,
    required this.lookX,
    required this.lookY,
    required this.lookMagnitudeX,
    required this.lookMagnitudeY,
  });

  Map<String, num> toJson() => {
        'phase': phase,
        'bob': bob,
        'blink': blink,
        'blinkPhase': blinkPhase,
        'saccade': saccade,
        'saccadePhase': saccadePhase,
        'lookX': lookX,
        'lookY': lookY,
        'lookMX': lookMagnitudeX,
        'lookMY': lookMagnitudeY,
      };

  @override
  bool operator ==(Object other) =>
      other is MotionSeeds &&
      phase == other.phase &&
      bob == other.bob &&
      blink == other.blink &&
      blinkPhase == other.blinkPhase &&
      saccade == other.saccade &&
      saccadePhase == other.saccadePhase &&
      lookX == other.lookX &&
      lookY == other.lookY &&
      lookMagnitudeX == other.lookMagnitudeX &&
      lookMagnitudeY == other.lookMagnitudeY;

  @override
  int get hashCode => Object.hash(
        phase,
        bob,
        blink,
        blinkPhase,
        saccade,
        saccadePhase,
        lookX,
        lookY,
        lookMagnitudeX,
        lookMagnitudeY,
      );
}

/// Saccade foreshortening coefficients for one frame.
class MotionWrap {
  /// Horizontal foreshortening shared by both eyes.
  final double magnitudeX;

  /// Side-dependent horizontal foreshortening.
  final double side;

  /// Vertical foreshortening.
  final double scaleY;

  /// Side-dependent rotation in degrees.
  final double rotation;

  /// Creates secondary-eye saccade wrap coefficients.
  const MotionWrap({
    required this.magnitudeX,
    required this.side,
    required this.scaleY,
    required this.rotation,
  });

  Map<String, double> toJson() => {
        'mx': magnitudeX,
        'side': side,
        'sy': scaleY,
        'rot': rotation,
      };
}

/// One deterministic frame of every idle-motion channel.
class MotionFrame {
  /// Mad-expression tremor translation in view-box units.
  final (double, double) shake;

  /// Horizontal and vertical breathing scales.
  final (double, double) breathe;

  /// Vertical body translation in view-box units.
  final double bob;

  /// Shared eye translation in view-box units.
  final (double, double) saccade;

  /// Held-thinking seesaw phase from -1 to 1.
  final double thinkingPhase;

  /// Vertical eye scale, where 1 is open.
  final double blink;

  /// Secondary-eye foreshortening for the current saccade.
  final MotionWrap wrap;

  /// Creates one evaluated motion frame.
  const MotionFrame({
    required this.shake,
    required this.breathe,
    required this.bob,
    required this.saccade,
    required this.thinkingPhase,
    required this.blink,
    required this.wrap,
  });

  Map<String, Object> toJson() => {
        'shake': [shake.$1, shake.$2],
        'breathe': [breathe.$1, breathe.$2],
        'bob': bob,
        'saccade': [saccade.$1, saccade.$2],
        'rockp': thinkingPhase,
        'blink': blink,
        'wrap': wrap.toJson(),
      };
}

int _jsRound(double value) => (value + 0.5).floor();

double _round2(double value) => _jsRound(value * 100) / 100;

/// Derives the exact CSS motion values from an existing trait reader.
MotionSeeds motionSeeds(Traits traits) {
  final int blink = _jsRound(traits.numIn('motion.blink', 3500, 6500));
  final int saccade = _jsRound(traits.numIn('motion.saccade', 4200, 7600));
  final double lookX = _round2(traits.numIn('motion.lookX', 1, 2.2));
  final double lookY = _round2(traits.numIn('motion.lookY', 0.8, 1.7));
  return MotionSeeds(
    phase: _jsRound(traits.numIn('motion.phase', 0, 2800)),
    bob: _jsRound(traits.numIn('motion.bob', 0, 3400)),
    blink: blink,
    blinkPhase:
        _jsRound(traits.numIn('motion.blinkPhase', 0, blink.toDouble())),
    saccade: saccade,
    saccadePhase:
        _jsRound(traits.numIn('motion.saccadePhase', 0, saccade.toDouble())),
    lookX: lookX * (traits.boolIn('motion.lookXFlip') ? -1 : 1),
    lookY: lookY * (traits.boolIn('motion.lookYFlip') ? -1 : 1),
    lookMagnitudeX: lookX,
    lookMagnitudeY: lookY,
  );
}

/// Derives one hiblob's motion values from its seed and trait options.
MotionSeeds motionSeedsFor(
  String name, {
  bool normalize = true,
  TraitOverrides? traits,
}) =>
    motionSeeds(
      traitsFor(name, normalize: normalize, overrides: traits),
    );

double _cycle(double time, double phase, double period) {
  final double value = (time + phase) / period;
  return value - value.floor();
}

double _alternate(double time, double phase, double period) {
  final double value = (time + phase) / period;
  final int iteration = value.floor();
  final double fraction = value - iteration;
  return iteration.isOdd ? 1 - fraction : fraction;
}

double _stops(double value, List<List<double>> table, int column) {
  for (var index = table.length - 1; index >= 0; index--) {
    final List<double> row = table[index];
    if (value < row[0]) continue;
    if (index + 1 == table.length) return row[column];
    final List<double> next = table[index + 1];
    final double span = next[0] - row[0];
    if (span <= 0) return row[column];
    return row[column] +
        (next[column] - row[column]) * ((value - row[0]) / span);
  }
  return table.first[column];
}

const List<List<double>> _saccadeStops = [
  [0, 0, 0],
  [0.15, 0, 0],
  [0.165, -0.8, -0.9],
  [0.31, -0.8, -0.9],
  [0.325, 1, 0.1],
  [0.47, 1, 0.1],
  [0.485, -0.15, 0.85],
  [0.63, -0.15, 0.85],
  [0.645, 0.75, -0.8],
  [0.79, 0.75, -0.8],
  [0.805, -1, -0.15],
  [0.985, -1, -0.15],
  [1, 0, 0],
];

const List<List<double>> _wrapStops = [
  [0, 0, 0, 0, 0],
  [0.15, 0, 0, 0, 0],
  [0.165, -0.0176, 0.008, -0.027, 0.648],
  [0.31, -0.0176, 0.008, -0.027, 0.648],
  [0.325, -0.022, -0.01, -0.003, 0.09],
  [0.47, -0.022, -0.01, -0.003, 0.09],
  [0.485, -0.0033, 0.0015, -0.0255, -0.115],
  [0.63, -0.0033, 0.0015, -0.0255, -0.115],
  [0.645, -0.0165, -0.0075, -0.024, -0.54],
  [0.79, -0.0165, -0.0075, -0.024, -0.54],
  [0.805, -0.022, 0.01, -0.0045, 0.135],
  [0.985, -0.022, 0.01, -0.0045, 0.135],
  [1, 0, 0, 0, 0],
];

const List<List<double>> _shakeStops = [
  [0, 0.62, -0.34],
  [0.25, -0.7, 0.22],
  [0.5, 0.38, 0.66],
  [0.75, -0.44, -0.6],
  [1, 0.62, -0.34],
];

/// Duration of one breathe iteration before alternating direction.
const double breatheMilliseconds = 2800;

/// Duration of one bob iteration before alternating direction.
const double bobMilliseconds = 3400;

/// Duration of one held-thinking seesaw loop.
const double thinkingMilliseconds = 900;

/// Duration of one held-mad tremor loop.
const double shakeMilliseconds = 112;

/// Duration of a transition into a non-idle expression.
const int expressionEnterMilliseconds = 300;

/// Duration of a transition back to idle.
const int expressionExitMilliseconds = 400;

/// Duration of an ambient-motion amplitude change.
const int ambientRampMilliseconds = 400;

/// Duration of the hover lift entering.
const int hoverEnterMilliseconds = 220;

/// Duration of the hover lift leaving.
const int hoverExitMilliseconds = 160;

/// Solves a CSS cubic Bézier timing function at elapsed fraction [x].
double cubicBezier(
  double x,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final double cx = 3 * x1;
  final double bx = 3 * (x2 - x1) - cx;
  final double ax = 1 - cx - bx;
  final double cy = 3 * y1;
  final double by = 3 * (y2 - y1) - cy;
  final double ay = 1 - cy - by;
  var parameter = x;
  for (var iteration = 0; iteration < 8; iteration++) {
    final double error =
        ((ax * parameter + bx) * parameter + cx) * parameter - x;
    if (error.abs() < 1e-5) break;
    final double derivative = (3 * ax * parameter + 2 * bx) * parameter + cx;
    if (derivative.abs() < 1e-6) break;
    parameter -= error / derivative;
  }
  return ((ay * parameter + by) * parameter + cy) * parameter;
}

/// Evaluates the CSS `ease-in-out` curve.
double easeInOut(double value) => cubicBezier(value, 0.42, 0, 0.58, 1);

/// Evaluates the CSS `ease-in` curve.
double easeIn(double value) => cubicBezier(value, 0.42, 0, 1, 1);

/// Evaluates the CSS `ease-out` curve.
double easeOut(double value) => cubicBezier(value, 0, 0, 0.58, 1);

/// Evaluates the authored expression-entry curve.
double expressionEnterEase(double value) =>
    cubicBezier(value, 0.45, 0.05, 0.5, 1);

/// Evaluates the authored hover reaction curve.
double hoverEase(double value) => cubicBezier(value, 0.23, 1, 0.32, 1);

/// Evaluates every deterministic motion channel at [elapsedMilliseconds].
MotionFrame motionAt(
  MotionSeeds seeds,
  double elapsedMilliseconds,
  double amplitude, {
  double shake = 0,
}) {
  final double breathe = easeInOut(
    _alternate(
      elapsedMilliseconds,
      seeds.phase.toDouble(),
      breatheMilliseconds,
    ),
  );
  final double bob = easeInOut(
    _alternate(
      elapsedMilliseconds,
      seeds.bob.toDouble(),
      bobMilliseconds,
    ),
  );
  final double saccade = _cycle(
    elapsedMilliseconds,
    seeds.saccadePhase.toDouble(),
    seeds.saccade.toDouble(),
  );
  final double shakeCycle = _cycle(elapsedMilliseconds, 0, shakeMilliseconds);
  final double thinkingCycle =
      _cycle(elapsedMilliseconds, 0, thinkingMilliseconds);
  final double thinkingPhase = thinkingCycle < 0.5
      ? 1 - 2 * easeInOut(thinkingCycle * 2)
      : -1 + 2 * easeInOut(thinkingCycle * 2 - 1);
  final double blinkCycle = _cycle(
    elapsedMilliseconds,
    seeds.blinkPhase.toDouble(),
    seeds.blink.toDouble(),
  );
  final double blink = blinkCycle < 0.972
      ? 1
      : blinkCycle < 0.986
          ? 1 - 0.92 * amplitude * easeIn((blinkCycle - 0.972) / 0.014)
          : 1 - 0.92 * amplitude * (1 - easeOut((blinkCycle - 0.986) / 0.014));

  return MotionFrame(
    shake: (
      _stops(shakeCycle, _shakeStops, 1) * shake,
      _stops(shakeCycle, _shakeStops, 2) * shake,
    ),
    breathe: (
      1 + 0.022 * amplitude * breathe,
      1 - 0.018 * amplitude * breathe,
    ),
    bob: -1.1 * amplitude * bob,
    saccade: (
      _stops(saccade, _saccadeStops, 1) * seeds.lookX * amplitude,
      _stops(saccade, _saccadeStops, 2) * seeds.lookY * amplitude,
    ),
    thinkingPhase: thinkingPhase,
    blink: blink,
    wrap: MotionWrap(
      magnitudeX:
          _stops(saccade, _wrapStops, 1) * seeds.lookMagnitudeX * amplitude,
      side: _stops(saccade, _wrapStops, 2) * seeds.lookX * amplitude,
      scaleY: _stops(saccade, _wrapStops, 3) * seeds.lookMagnitudeY * amplitude,
      rotation: _stops(saccade, _wrapStops, 4) *
          seeds.lookX *
          seeds.lookY *
          amplitude,
    ),
  );
}

/// Linearly interpolates every expression channel.
Pose lerpPose(Pose? from, Pose? to, double progress) {
  final Pose a = from ?? identityPose;
  final Pose b = to ?? identityPose;
  double lerp(double start, double end) =>
      start * (1 - progress) + end * progress;
  return Pose(
    esx: lerp(a.esx, b.esx),
    esy: lerp(a.esy, b.esy),
    tilt: lerp(a.tilt, b.tilt),
    edy: lerp(a.edy, b.edy),
    edx: lerp(a.edx, b.edx),
    esx2: lerp(a.esx2, b.esx2),
    esy2: lerp(a.esy2, b.esy2),
    tilt2: lerp(a.tilt2, b.tilt2),
    edy2: lerp(a.edy2, b.edy2),
    lock: lerp(a.lock, b.lock),
    heat: lerp(a.heat, b.heat),
    shake: lerp(a.shake, b.shake),
    rock: lerp(a.rock, b.rock),
    bdy: lerp(a.bdy, b.bdy),
  );
}
