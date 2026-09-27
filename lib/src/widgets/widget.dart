/// The hiblob widgets: a static avatar and an animated one.
///
/// ```dart
/// import 'package:hiblob/flutter.dart';
///
/// const Hiblob(name: 'ada@example.com', size: 48)
///
/// AnimatedHiblob(
///   name: 'ada@example.com',
///   size: 120,
///   animation: HiblobAnimation.always,
/// )
/// ```
library;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';
import 'package:hiblob/hiblob.dart';

import 'painter.dart';

export 'package:hiblob/hiblob.dart'
    show
        Backdrop,
        Expression,
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
export 'painter.dart' show AnimatedHiblobPainter, HiblobPainter;
export 'renderer.dart' show HiblobRenderer;

/// How [AnimatedHiblob] runs its ambient motion.
enum HiblobAnimation {
  /// Motion runs continuously.
  always,

  /// Motion ramps in while a pointer hovers the widget and idles out when it
  /// leaves — the right default for lists.
  hover,
}

/// A static hiblob.
///
/// ```dart
/// const Hiblob(
///   name: user.email,
///   size: 64,
///   semanticLabel: 'Avatar of ${user.displayName}',
/// )
/// ```
///
/// [size] pins a square edge; without it the widget fills its constraints
/// with the largest centered square. With [semanticLabel] set, the figure is
/// exposed to assistive technology as an image with that label.
class Hiblob extends StatelessWidget {
  /// The name this hiblob stands for.
  final String name;

  /// A fixed square edge, or `null` to fill the constraints.
  final double? size;

  /// Color, trait, and expression options.
  final HiblobOptions options;

  /// The assistive-technology label, if any.
  final String? semanticLabel;

  /// Creates a static hiblob.
  const Hiblob({
    super.key,
    required this.name,
    this.size,
    this.options = const HiblobOptions(),
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final painter = HiblobPainter(
      HiblobRenderer(name: name, options: options),
    );
    Widget body;
    final fixed = size;
    if (fixed != null) {
      body = SizedBox(
        width: fixed,
        height: fixed,
        child: CustomPaint(painter: painter, size: Size.square(fixed)),
      );
    } else {
      body = LayoutBuilder(builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final edge = side.isFinite && side > 0 ? side : 100.0;
        return CustomPaint(painter: painter, size: Size.square(edge));
      });
    }
    final label = semanticLabel;
    if (label == null) return body;
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: body,
    );
  }
}

/// An animated hiblob: seeded breathe, bob, blinks, and glances.
///
/// ```dart
/// AnimatedHiblob(
///   name: user.email,
///   size: 120,
///   animation: HiblobAnimation.always,
///   options: const HiblobOptions(expression: thinking),
/// )
/// ```
///
/// With [HiblobAnimation.hover], ambient motion ramps in while a pointer is
/// over the widget and idles out when it leaves — the right default in
/// lists, where every row would otherwise be moving at once.
///
/// Set [active] to `false` when the widget is known to be off-screen. The
/// widget follows [TickerMode], and when the platform requests reduced
/// motion (`MediaQueryData.disableAnimations`) it paints the motionless
/// frame instead; opt out with [respectReducedMotion] only if the
/// application offers an equivalent control.
///
/// Expression (and name) changes crossfade between the old and new figure.
class AnimatedHiblob extends StatefulWidget {
  /// The name this hiblob stands for.
  final String name;

  /// A fixed square edge, or `null` to fill the constraints.
  final double? size;

  /// Color, trait, and expression options.
  final HiblobOptions options;

  /// The ambient motion mode.
  final HiblobAnimation animation;

  /// Whether animation time advances; set `false` when off-screen.
  final bool active;

  /// Whether `MediaQueryData.disableAnimations` freezes the figure.
  final bool respectReducedMotion;

  /// The assistive-technology label, if any.
  final String? semanticLabel;

  /// Creates an animated hiblob.
  const AnimatedHiblob({
    super.key,
    required this.name,
    this.size,
    this.options = const HiblobOptions(),
    this.animation = HiblobAnimation.always,
    this.active = true,
    this.respectReducedMotion = true,
    this.semanticLabel,
  });

  @override
  State<AnimatedHiblob> createState() => _AnimatedHiblobState();
}

class _AnimatedHiblobState extends State<AnimatedHiblob>
    with TickerProviderStateMixin {
  late HiblobRenderer _renderer;
  HiblobRenderer? _previous;
  late final Ticker _ticker;
  Duration? _lastTick;
  final ValueNotifier<double> _elapsedMs = ValueNotifier<double>(0);
  late final AnimationController _ramp;
  late final AnimationController _fade;
  bool _hovering = false;

  static const Duration _rampDuration = Duration(milliseconds: 220);
  static const Duration _fadeDuration = Duration(milliseconds: 240);

  @override
  void initState() {
    super.initState();
    _renderer = HiblobRenderer(name: widget.name, options: widget.options);
    _ramp = AnimationController(vsync: this, duration: _rampDuration)
      ..value = widget.animation == HiblobAnimation.always ? 1.0 : 0.0;
    _fade = AnimationController(vsync: this, duration: _fadeDuration)
      ..value = 1.0;
    _ticker = createTicker(_onTick)..start();
  }

  bool get _reducedMotion =>
      widget.respectReducedMotion && MediaQuery.of(context).disableAnimations;

  bool get _shouldAdvance =>
      widget.active &&
      !_reducedMotion &&
      (widget.animation == HiblobAnimation.always || _hovering);

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null || !_shouldAdvance) return;
    final dt = (elapsed - last).inMicroseconds / 1000.0;
    _elapsedMs.value = (_elapsedMs.value + dt) % 86400000;
  }

  void _onEnter(PointerEvent _) {
    _hovering = true;
    if (widget.animation == HiblobAnimation.hover && !_reducedMotion) {
      _ramp.forward();
    }
  }

  void _onExit(PointerEvent _) {
    _hovering = false;
    if (widget.animation == HiblobAnimation.hover) {
      _ramp.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedHiblob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.name != oldWidget.name || widget.options != oldWidget.options) {
      _previous = _renderer;
      _renderer = HiblobRenderer(name: widget.name, options: widget.options);
      _fade.forward(from: 0);
    }
    if (widget.animation != oldWidget.animation) {
      if (widget.animation == HiblobAnimation.always) {
        _ramp.value = 1.0;
      } else if (!_hovering) {
        _ramp.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final painter = AnimatedHiblobPainter(
      renderer: _renderer,
      previous: _previous,
      seeds: motionSeedsFor(widget.name, options: widget.options),
      elapsedMs: _elapsedMs,
      rampOf: () =>
          widget.animation == HiblobAnimation.always ? 1.0 : _ramp.value,
      fadeOf: () => _fade.value,
      repaint: Listenable.merge([_elapsedMs, _ramp, _fade]),
    );
    Widget body;
    final fixed = widget.size;
    if (fixed != null) {
      body = SizedBox(
        width: fixed,
        height: fixed,
        child: CustomPaint(painter: painter, size: Size.square(fixed)),
      );
    } else {
      body = LayoutBuilder(builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final edge = side.isFinite && side > 0 ? side : 100.0;
        return CustomPaint(painter: painter, size: Size.square(edge));
      });
    }
    body = MouseRegion(onEnter: _onEnter, onExit: _onExit, child: body);
    final label = widget.semanticLabel;
    if (label != null) {
      body = Semantics(
        label: label,
        image: true,
        excludeSemantics: true,
        child: body,
      );
    }
    return body;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ramp.dispose();
    _fade.dispose();
    _elapsedMs.dispose();
    super.dispose();
  }
}
