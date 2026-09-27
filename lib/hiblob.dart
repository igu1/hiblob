/// The pure Dart core of hiblob: deterministic geometric blob avatars from
/// any string.
///
/// A hiblob always stands for somebody — a user, a bot, a team, a repo — so
/// the value it is generated from is that somebody's `name`: a username, a
/// display name, an email, a handle, an id. Any string works, and the same
/// string always renders the same hiblob.
///
/// This library imports neither Flutter nor `dart:ui`, so it runs anywhere
/// Dart runs. For ready-made Flutter widgets, import
/// `package:hiblob/flutter.dart` instead — it re-exports everything here.
///
/// ```dart
/// import 'package:hiblob/hiblob.dart';
///
/// final traits = traitsFor('ada@example.com');
/// final figure = resolve('ada@example.com');
/// final frame = motionAt(motionSeedsFor('ada@example.com'), 1200, ramp: 1);
/// ```
library;

export 'src/color.dart'
    show argbToHex, blendArgb, hexToArgb, hslToArgb, relativeLuminance;
export 'src/expressions.dart'
    show
        Expression,
        expressions,
        happy,
        idle,
        love,
        mad,
        scared,
        shy,
        sick,
        sleepy,
        smug,
        sad,
        surprised,
        thinking,
        unsure,
        wink;
export 'src/geometry.dart'
    show
        ClosePath,
        CubicTo,
        GeometryCommand,
        GeometryPath,
        LineTo,
        MoveTo,
        Pt,
        QuadraticTo,
        RadialWave,
        circle,
        droplet,
        ellipse,
        halfDisc,
        polyline,
        quad,
        radialBlob,
        rotatePt,
        roundedPolygon,
        roundedRect,
        smoothClosed,
        star,
        superellipse;
export 'src/layout.dart' show EyeGroup, ResolvedHiblob, resolve, viewBoxSize;
export 'src/motion.dart'
    show MotionFrame, MotionSeeds, motionAt, motionSeedsFor;
export 'src/options.dart' show Backdrop, HiblobOptions, PaletteKeys;
export 'src/traits.dart' show shapeBands, toneBands, traitKeys, traitsFor;
