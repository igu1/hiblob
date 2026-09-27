/// Deterministic elapsed-time motion: breathe, bob, blink, and glances.
///
/// Motion is a pure function of (seed, elapsed time, ramp) — no controllers,
/// no state. The same name at the same moment is at the same point in its
/// motion, on every platform.
library;

import 'dart:math' as math;

import 'hash.dart';
import 'options.dart';

/// The per-name random periods and phases motion reads.
class MotionSeeds {
  final double bobPhase;
  final double bobPeriod;
  final double breathePhase;
  final double breathePeriod;
  final double blinkPeriod;
  final double blinkOffset;
  final double glancePeriod;
  final double glanceSeed;

  const MotionSeeds({
    required this.bobPhase,
    required this.bobPeriod,
    required this.breathePhase,
    required this.breathePeriod,
    required this.blinkPeriod,
    required this.blinkOffset,
    required this.glancePeriod,
    required this.glanceSeed,
  });
}

/// One instant of motion, in view-box units.
class MotionFrame {
  /// Vertical body offset (positive is down).
  final double bodyY;

  /// Vertical body scale around the body center (breathe).
  final double bodyScaleY;

  /// Eye closure in `[0, 1]`; 1 is fully closed.
  final double blink;

  /// Horizontal eye offset (glance), in `[-2, 2]` view-box units.
  final double gazeX;

  /// Vertical eye offset (glance), in `[-2, 2]` view-box units.
  final double gazeY;

  const MotionFrame({
    this.bodyY = 0,
    this.bodyScaleY = 1,
    this.blink = 0,
    this.gazeX = 0,
    this.gazeY = 0,
  });

  /// The motionless frame a static hiblob paints.
  static const MotionFrame zero = MotionFrame();

  @override
  bool operator ==(Object other) =>
      other is MotionFrame &&
      other.bodyY == bodyY &&
      other.bodyScaleY == bodyScaleY &&
      other.blink == blink &&
      other.gazeX == gazeX &&
      other.gazeY == gazeY;

  @override
  int get hashCode => Object.hash(bodyY, bodyScaleY, blink, gazeX, gazeY);

  @override
  String toString() =>
      'MotionFrame(bodyY: $bodyY, scaleY: $bodyScaleY, blink: $blink, '
      'gaze: ($gazeX, $gazeY))';
}

/// Reads the motion seeds for [name].
MotionSeeds motionSeedsFor(String name,
    {HiblobOptions options = const HiblobOptions()}) {
  final seed = options.normalize ? name.trim().toLowerCase() : name;
  return MotionSeeds(
    bobPhase: stream(seed, 'motion.bob.phase') * 2 * math.pi,
    bobPeriod: 2.4 + stream(seed, 'motion.bob.period') * 1.2,
    breathePhase: stream(seed, 'motion.breathe.phase') * 2 * math.pi,
    breathePeriod: 3.0 + stream(seed, 'motion.breathe.period') * 1.5,
    blinkPeriod: 2.8 + stream(seed, 'motion.blink.period') * 2.7,
    blinkOffset: stream(seed, 'motion.blink.offset') * 0.35,
    glancePeriod: 1.8 + stream(seed, 'motion.glance.period') * 2.0,
    glanceSeed: stream(seed, 'motion.glance.seed'),
  );
}

double _glanceComponent(double glanceSeed, int index, String axis) {
  final v = stream('glance/$glanceSeed/$index', axis);
  return v * 2 - 1; // -1..1
}

double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

/// The motion frame at [elapsedMs] for [seeds].
///
/// [ramp] in `[0, 1]` scales the ambient motion up from a quiet idle (0) to
/// full liveliness (1) — the hover mode ramps it with the pointer. The frame
/// at elapsed 0 is always blink-free, so a paused hiblob never shows half a
/// blink.
MotionFrame motionAt(MotionSeeds seeds, double elapsedMs, {double ramp = 0}) {
  final t = elapsedMs / 1000;
  final ambient = 0.35 + 0.65 * ramp.clamp(0.0, 1.0);

  final bob = math.sin(2 * math.pi * t / seeds.bobPeriod + seeds.bobPhase) *
      1.5 *
      ambient;
  final bodyY = bob - 2.0 * ramp;
  final bodyScaleY = 1 +
      math.sin(2 * math.pi * t / seeds.breathePeriod + seeds.breathePhase) *
          0.012 *
          ambient;

  // Blink: one short window inside each blink period, shaped like a half
  // sine so it closes and opens smoothly.
  final bt = ((t + seeds.blinkOffset * seeds.blinkPeriod) % seeds.blinkPeriod) /
      seeds.blinkPeriod;
  const windowStart = 0.55;
  const windowLength = 0.055;
  var blink = 0.0;
  if (bt >= windowStart && bt <= windowStart + windowLength) {
    blink = math.sin((bt - windowStart) / windowLength * math.pi);
  }

  // Glances: a new target each glance period, approached with an ease-out in
  // the first 12% of the period, so saccades snap and then hold.
  final index = (t / seeds.glancePeriod).floor();
  final prevIndex = index - 1;
  final frac = t / seeds.glancePeriod - index;
  final ease = frac < 0.12 ? _easeOutCubic(frac / 0.12) : 1.0;
  double glance(String axis) {
    final cur = _glanceComponent(seeds.glanceSeed, index, axis);
    final prev = _glanceComponent(seeds.glanceSeed, prevIndex, axis);
    return (prev + (cur - prev) * ease) * 1.8 * ambient;
  }

  return MotionFrame(
    bodyY: bodyY,
    bodyScaleY: bodyScaleY,
    blink: blink,
    gazeX: glance('x'),
    gazeY: glance('y'),
  );
}
