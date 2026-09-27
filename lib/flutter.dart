/// The Flutter widget layer of the hiblob SDK.
///
/// ```dart
/// import 'package:hiblob/flutter.dart';
///
/// AnimatedHiblob(name: 'alain@example.com', size: 48)
/// ```
///
/// The widgets paint the deterministic layout through
/// `dart:ui` primitives — the same math the parity fixture pins against the
/// reference vectors. For the pure, Flutter-independent engine (hash, traits,
/// palette, layout), import `package:hiblob/hiblob.dart` instead.
library;

export 'package:hiblob/hiblob.dart'
    show
        Backdrop,
        BackdropGeometry,
        HiblobOptions,
        Palette,
        Pose,
        MotionFrame,
        MotionSeeds,
        MotionWrap,
        motionAt,
        motionSeedsFor,
        Expression,
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
        expressions;

export 'src/flutter/animated_painter.dart' show AnimatedHiblobPainter;
export 'src/flutter/animated_renderer.dart'
    show AnimatedHiblobFrame, AnimatedHiblobRenderer;
export 'src/flutter/animated_widget.dart' show AnimatedHiblob, HiblobAnimation;
export 'src/flutter/painter.dart' show HiblobPainter;
export 'src/flutter/renderer.dart' show HiblobRenderer;
export 'src/flutter/widget.dart' show Hiblob;
