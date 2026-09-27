/// Expression poses for the hiblob engine.
library;

import 'color.dart';
import 'styles/compose.dart';

/// Every channel an expression may change.
class Pose {
  final double esx;
  final double esy;
  final double tilt;
  final double edy;
  final double edx;
  final double esx2;
  final double esy2;
  final double tilt2;
  final double edy2;
  final double lock;
  final double heat;
  final double shake;
  final double rock;
  final double bdy;

  const Pose({
    this.esx = 1,
    this.esy = 1,
    this.tilt = 0,
    this.edy = 0,
    this.edx = 0,
    this.esx2 = 0,
    this.esy2 = 0,
    this.tilt2 = 0,
    this.edy2 = 0,
    this.lock = 0,
    this.heat = 0,
    this.shake = 0,
    this.rock = 0,
    this.bdy = 0,
  });

  Map<String, double> toJson() => {
        'esx': esx,
        'esy': esy,
        'tilt': tilt,
        'edy': edy,
        'edx': edx,
        'esx2': esx2,
        'esy2': esy2,
        'tilt2': tilt2,
        'edy2': edy2,
        'lock': lock,
        'heat': heat,
        'shake': shake,
        'rock': rock,
        'bdy': bdy,
      };

  @override
  bool operator ==(Object other) =>
      other is Pose &&
      esx == other.esx &&
      esy == other.esy &&
      tilt == other.tilt &&
      edy == other.edy &&
      edx == other.edx &&
      esx2 == other.esx2 &&
      esy2 == other.esy2 &&
      tilt2 == other.tilt2 &&
      edy2 == other.edy2 &&
      lock == other.lock &&
      heat == other.heat &&
      shake == other.shake &&
      rock == other.rock &&
      bdy == other.bdy;

  @override
  int get hashCode => Object.hash(esx, esy, tilt, edy, edx, esx2, esy2, tilt2,
      edy2, lock, heat, shake, rock, bdy);
}

/// A named pose and its optional palette tint target.
class Expression {
  final String name;
  final Pose pose;
  final Tint? tint;

  const Expression(this.name, this.pose, {this.tint});

  @override
  bool operator ==(Object other) =>
      other is Expression &&
      name == other.name &&
      pose == other.pose &&
      tint == other.tint;

  @override
  int get hashCode => Object.hash(name, pose, tint);
}

const Pose identityPose = Pose();

const Expression idle = Expression('idle', identityPose);
const Expression happy = Expression(
  'happy',
  Pose(
      esx: 1.72,
      esy: 0.3,
      tilt: 8,
      edy: -1.5,
      edx: 1.5,
      esx2: 0.08,
      esy2: 0.05,
      tilt2: -16,
      lock: 1,
      bdy: -2.2),
);
const Expression sad = Expression(
  'sad',
  Pose(
      esx: 0.6,
      esy: 0.56,
      tilt: 26,
      edy: 3.6,
      edx: 1.9,
      esx2: -0.05,
      esy2: -0.07,
      tilt2: -7,
      lock: 1,
      bdy: 2.6),
);
const Expression mad = Expression(
  'mad',
  Pose(
      esx: 1.85,
      esy: 0.26,
      tilt: -33,
      edy: 0.4,
      edx: 0.6,
      esy2: -0.03,
      tilt2: 5,
      lock: 1,
      heat: 0.62,
      shake: 0.55,
      bdy: 0.8),
  tint: hot,
);
const Expression surprised = Expression(
  'surprised',
  Pose(
      esx: 1.34,
      esy: 1.2,
      tilt: -6,
      edy: -1.05,
      edx: 0.5,
      esx2: 0.05,
      esy2: 0.07,
      tilt2: 3,
      lock: 1,
      bdy: -1.4),
);
const Expression wink = Expression(
  'wink',
  Pose(
      esx: 1.32,
      esy: 0.76,
      tilt: 5,
      edy: -0.6,
      edx: 0.8,
      esx2: 0.26,
      esy2: -0.56,
      tilt2: -11,
      lock: 1,
      bdy: -1.1),
);
const Expression sleepy = Expression(
  'sleepy',
  Pose(
      esx: 1.14,
      esy: 0.22,
      edy: 2.4,
      edx: 0.3,
      esx2: -0.04,
      esy2: 0.03,
      tilt2: 4,
      lock: 1,
      bdy: 1.2),
);
const Expression smug = Expression(
  'smug',
  Pose(
      esx: 1.3,
      esy: 0.42,
      tilt: 18,
      edy: -0.5,
      edx: 0.5,
      esx2: 0.06,
      esy2: -0.06,
      tilt2: -36,
      lock: 1,
      bdy: -1),
);
const Expression unsure = Expression(
  'unsure',
  Pose(
      esx: 0.95,
      esy: 1.02,
      tilt: 4,
      edy: -0.2,
      edx: 0.3,
      esx2: 0.24,
      esy2: -0.44,
      tilt2: -18,
      lock: 1),
);
const Expression scared = Expression(
  'scared',
  Pose(
      esx: 0.78,
      esy: 0.96,
      tilt: -12,
      edy: -1.5,
      edx: -0.8,
      esx2: -0.04,
      esy2: 0.05,
      tilt2: 4,
      lock: 1,
      shake: 0.35,
      bdy: -0.6),
);
const Expression love = Expression(
  'love',
  Pose(
      esx: 0.86,
      esy: 1.28,
      tilt: -14,
      edy: -0.5,
      edx: -0.35,
      esx2: 0.05,
      esy2: 0.06,
      tilt2: 6,
      lock: 1,
      heat: 0.6,
      bdy: -1.6),
  tint: rose,
);
const Expression shy = Expression(
  'shy',
  Pose(
      esx: 0.62,
      esy: 0.5,
      tilt: 10,
      edy: 1.4,
      edx: -0.2,
      esx2: -0.05,
      esy2: -0.04,
      tilt2: -8,
      lock: 1,
      heat: 0.55,
      bdy: 0.9),
  tint: blush,
);
const Expression sick = Expression(
  'sick',
  Pose(
      esx: 1.25,
      esy: 0.34,
      tilt: 20,
      edy: 1.8,
      edx: 0.8,
      esx2: 0.05,
      esy2: -0.05,
      tilt2: -6,
      lock: 1,
      heat: 0.6,
      shake: 0.18,
      bdy: 1.4),
  tint: bile,
);
const Expression thinking = Expression(
  'thinking',
  Pose(
      esx: 1.15,
      esy: 0.62,
      edy: 4.2,
      edx: 0.4,
      esx2: 0.02,
      esy2: 0.06,
      edy2: -8.4,
      lock: 1,
      rock: 0.8,
      bdy: -0.4),
);

const List<Expression> expressions = [
  idle,
  happy,
  sad,
  mad,
  surprised,
  wink,
  sleepy,
  smug,
  unsure,
  scared,
  love,
  shy,
  sick,
  thinking,
];

/// Bakes a static pose into the eye geometry and body offset.
HiblobLayout bakePose(HiblobLayout layout, Pose pose) {
  return HiblobLayout(
    shape: layout.shape,
    body: layout.body,
    face: layout.face,
    eyes: [
      for (var i = 0; i < layout.eyes.length; i++)
        Eye(
          layout.eyes[i].cx + pose.edx * (i == 0 ? -1 : 1),
          layout.eyes[i].cy + pose.edy + (i == 1 ? pose.edy2 : 0),
          layout.eyes[i].rx * (pose.esx + (i == 1 ? pose.esx2 : 0)),
          layout.eyes[i].ry * (pose.esy + (i == 1 ? pose.esy2 : 0)),
          layout.eyes[i].n,
          layout.eyes[i].rot * (1 - pose.lock) +
              (pose.tilt + (i == 1 ? pose.tilt2 : 0)) * (i == 0 ? -1 : 1),
        ),
    ],
    petals: layout.petals,
    extra: layout.extra,
    draw: layout.draw,
    bodyOffsetY: pose.bdy,
  );
}

/// Resolves a tinting expression against the palette it is actually wearing.
Palette expressionPalette(Palette palette, Expression expression) {
  final Tint? target = expression.tint;
  if (target == null) return palette;
  final (String head, String eye) =
      tinted(palette[colorHead]!, palette[colorEye]!, target);
  return {
    ...palette,
    colorHead: mixHex(palette[colorHead]!, head, expression.pose.heat),
    colorEye: mixHex(palette[colorEye]!, eye, expression.pose.heat),
  };
}
