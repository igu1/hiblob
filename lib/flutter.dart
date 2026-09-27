/// The Flutter widget layer of hiblob.
///
/// ```dart
/// import 'package:hiblob/flutter.dart';
///
/// const Hiblob(name: 'ada@example.com', size: 48);
///
/// AnimatedHiblob(
///   name: 'ada@example.com',
///   size: 120,
///   animation: HiblobAnimation.always,
/// )
/// ```
///
/// The widgets paint the deterministic layout through `dart:ui` primitives.
/// For the pure, Flutter-independent engine (hash, traits, palette,
/// geometry, motion), import `package:hiblob/hiblob.dart` instead.
library;

export 'package:hiblob/hiblob.dart'
    show
        Backdrop,
        Expression,
        EyeGroup,
        GeometryPath,
        HiblobOptions,
        MotionFrame,
        MotionSeeds,
        ResolvedHiblob,
        expressions,
        happy,
        idle,
        love,
        mad,
        motionAt,
        motionSeedsFor,
        PaletteKeys,
        resolve,
        scared,
        shy,
        sick,
        sleepy,
        smug,
        sad,
        surprised,
        thinking,
        traitsFor,
        unsure,
        wink;
export 'src/widgets/painter.dart' show AnimatedHiblobPainter, HiblobPainter;
export 'src/widgets/renderer.dart' show HiblobRenderer, uiPathFrom;
export 'src/widgets/widget.dart' show AnimatedHiblob, Hiblob, HiblobAnimation;
