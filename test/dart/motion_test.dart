import 'package:test/test.dart';

import 'package:hiblob/hiblob.dart';

void main() {
  group('motion seeds', () {
    test('match reference values', () {
      expect(
        motionSeedsFor('alain'),
        const MotionSeeds(
          phase: 508,
          bob: 1170,
          blink: 3619,
          blinkPhase: 2957,
          saccade: 6179,
          saccadePhase: 1350,
          lookX: 1.95,
          lookY: -0.97,
          lookMagnitudeX: 1.95,
          lookMagnitudeY: 0.97,
        ),
      );
      expect(
        motionSeedsFor('ada'),
        const MotionSeeds(
          phase: 455,
          bob: 328,
          blink: 5328,
          blinkPhase: 58,
          saccade: 5844,
          saccadePhase: 561,
          lookX: -1.78,
          lookY: -1.36,
          lookMagnitudeX: 1.78,
          lookMagnitudeY: 1.36,
        ),
      );
    });

    test('independent names and channels do not synchronize', () {
      final List<MotionSeeds> seeds = [
        for (final String name in ['alain', 'ada', 'grace', 'linus'])
          motionSeedsFor(name),
      ];
      expect(seeds.map((MotionSeeds value) => value.phase).toSet().length, 4);
      for (final MotionSeeds value in seeds) {
        expect(value.phase, isNot(value.bob));
        expect(value.blink, inInclusiveRange(3500, 6500));
        expect(value.saccade, inInclusiveRange(4200, 7600));
      }
    });
  });

  group('elapsed-time frames', () {
    const MotionSeeds seeds = MotionSeeds(
      phase: 508,
      bob: 1170,
      blink: 3619,
      blinkPhase: 2957,
      saccade: 6179,
      saccadePhase: 1350,
      lookX: 1.95,
      lookY: -0.97,
      lookMagnitudeX: 1.95,
      lookMagnitudeY: 0.97,
    );

    test('match reference calculations at selected times', () {
      _expectFrame(
        motionAt(seeds, 0, 1, shake: 0.55),
        shake: (0.341, -0.18700000000000003),
        breathe: (1.001470229356656, 0.998797085071827),
        bob: -0.27170814718541325,
        saccade: (-1.56, 0.873),
        thinkingPhase: 1,
        blink: 1,
        wrap: (-0.03432, 0.0156, -0.026189999999999998, -1.225692),
      );
      _expectFrame(
        motionAt(seeds, 1234, 1, shake: 0.55),
        shake: (0.28914285714285864, -0.16500000000000065),
        breathe: (1.015462618780544, 0.9873487664522821),
        bob: -0.903594833714393,
        saccade: (1.95, -0.097),
        thinkingPhase: -0.7249387100885838,
        blink: 1,
        wrap: (-0.042899999999999994, -0.0195, -0.00291, -0.170235),
      );
      _expectFrame(
        motionAt(seeds, 5000, 1, shake: 0.55),
        shake: (-0.04871428571429122, -0.03300000000000846),
        breathe: (1.0000455442519844, 0.9999627365211037),
        bob: -0.0767684801351858,
        saccade: (0, 0),
        thinkingPhase: -0.9510907709234386,
        blink: 1,
        wrap: (0, 0, 0, 0),
      );
    });

    test('zero amplitude removes every ambient channel', () {
      for (var time = 0; time < 20000; time += 137) {
        final MotionFrame frame = motionAt(seeds, time.toDouble(), 0);
        expect(frame.breathe, (1, 1));
        expect(frame.bob, closeTo(0, 1e-12));
        expect(frame.saccade.$1, closeTo(0, 1e-12));
        expect(frame.saccade.$2, closeTo(0, 1e-12));
        expect(frame.blink, 1);
        expect(frame.wrap.magnitudeX, closeTo(0, 1e-12));
        expect(frame.wrap.side, closeTo(0, 1e-12));
        expect(frame.wrap.scaleY, closeTo(0, 1e-12));
        expect(frame.wrap.rotation, closeTo(0, 1e-12));
      }
    });

    test('blink closes once without inversion', () {
      final double closed = 0.986 * seeds.blink - seeds.blinkPhase;
      expect(motionAt(seeds, closed, 1).blink, closeTo(0.08, 1e-9));
      for (var index = 0; index < 4000; index++) {
        final double time = index * seeds.blink / 4000;
        expect(motionAt(seeds, time, 1).blink, greaterThan(0));
      }
    });

    test('saccades hold and preserve secondary-eye wrap', () {
      final List<double> values = [
        for (var index = 0; index < 600; index++)
          motionAt(seeds, index * seeds.saccade / 600, 1).saccade.$1,
      ];
      final int held = [
        for (var index = 1; index < values.length; index++)
          if ((values[index] - values[index - 1]).abs() < 1e-9) index,
      ].length;
      expect(held / values.length, greaterThan(0.8));
      final MotionFrame frame = motionAt(seeds, 1234, 1);
      expect(frame.wrap.side, isNot(0));
      expect(frame.wrap.rotation, isNot(0));
    });
  });

  group('expression morph', () {
    test('interpolation reaches exact endpoints', () {
      expect(lerpPose(idle.pose, happy.pose, 0), idle.pose);
      expect(lerpPose(idle.pose, happy.pose, 1), happy.pose);
      final Pose halfway = lerpPose(idle.pose, happy.pose, 0.5);
      expect(halfway.esx, closeTo((1 + happy.pose.esx) / 2, 1e-12));
      expect(halfway.bdy, closeTo(happy.pose.bdy / 2, 1e-12));
    });

    test('timings and curves match the motion spec', () {
      expect(expressionEnterMilliseconds, 300);
      expect(expressionExitMilliseconds, 400);
      expect(expressionEnterEase(0), closeTo(0, 1e-12));
      expect(expressionEnterEase(1), closeTo(1, 1e-12));
      expect(easeInOut(0.5), closeTo(0.5, 1e-9));
      expect(hoverEase(0), closeTo(0, 1e-12));
      expect(hoverEase(1), closeTo(1, 1e-12));
    });
  });
}

void _expectFrame(
  MotionFrame actual, {
  required (double, double) shake,
  required (double, double) breathe,
  required double bob,
  required (double, double) saccade,
  required double thinkingPhase,
  required double blink,
  required (double, double, double, double) wrap,
}) {
  expect(actual.shake.$1, closeTo(shake.$1, 1e-12));
  expect(actual.shake.$2, closeTo(shake.$2, 1e-12));
  expect(actual.breathe.$1, closeTo(breathe.$1, 1e-12));
  expect(actual.breathe.$2, closeTo(breathe.$2, 1e-12));
  expect(actual.bob, closeTo(bob, 1e-12));
  expect(actual.saccade.$1, closeTo(saccade.$1, 1e-12));
  expect(actual.saccade.$2, closeTo(saccade.$2, 1e-12));
  expect(actual.thinkingPhase, closeTo(thinkingPhase, 1e-12));
  expect(actual.blink, closeTo(blink, 1e-12));
  expect(actual.wrap.magnitudeX, closeTo(wrap.$1, 1e-12));
  expect(actual.wrap.side, closeTo(wrap.$2, 1e-12));
  expect(actual.wrap.scaleY, closeTo(wrap.$3, 1e-12));
  expect(actual.wrap.rotation, closeTo(wrap.$4, 1e-12));
}
