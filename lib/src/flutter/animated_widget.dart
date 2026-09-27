/// Lifecycle-safe animated hiblob widget.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

import 'package:hiblob/hiblob.dart' as core;

import 'animated_painter.dart';
import 'animated_renderer.dart';
import 'path.dart' show colorFromHex;
import 'widget.dart' show Hiblob;

/// How ambient motion is activated.
enum HiblobAnimation {
  /// Breathe, bob, blink, and saccades ramp in while a mouse hovers the widget.
  hover,

  /// Ambient motion remains active whenever the widget is ticker-enabled.
  always,
}

class _CoreCurve extends Curve {
  final double Function(double) evaluate;

  const _CoreCurve(this.evaluate);

  @override
  double transformInternal(double t) => evaluate(t);
}

const _CoreCurve _ambientCurve = _CoreCurve(core.easeOut);
const _CoreCurve _hoverCurve = _CoreCurve(core.hoverEase);

/// A hiblob with elapsed-time idle motion and expression morphing.
///
/// The deterministic loops use one shared monotonic clock, so widgets mounted
/// later join the same seeded phase rather than starting a new synchronized
/// crowd. Flutter's ticker lifecycle automatically follows [TickerMode]; set
/// [active] to false when an app's visibility model knows a list item is off
/// screen. Reduced motion is honored through `MediaQuery.disableAnimations`.
class AnimatedHiblob extends StatefulWidget {
  /// The public identity used to derive deterministic traits and motion.
  final String name;

  /// The square edge in logical pixels, or null to fill the parent constraints.
  final double? size;

  /// Generation, palette, backdrop, trait, and expression options.
  final core.HiblobOptions options;

  /// The optional assistive-technology label for this image.
  final String? semanticLabel;

  /// Whether ambient motion reacts to hover or remains continuously active.
  final HiblobAnimation animation;

  /// Whether controllers may tick and animated frames may be painted.
  final bool active;

  /// Whether `MediaQuery.disableAnimations` selects the static rendering path.
  final bool respectReducedMotion;

  /// Creates a deterministic animated hiblob.
  const AnimatedHiblob({
    super.key,
    required this.name,
    this.size,
    this.options = const core.HiblobOptions(),
    this.semanticLabel,
    this.animation = HiblobAnimation.hover,
    this.active = true,
    this.respectReducedMotion = true,
  });

  @override
  State<AnimatedHiblob> createState() => _AnimatedHiblobState();
}

class _AnimatedHiblobState extends State<AnimatedHiblob>
    with TickerProviderStateMixin {
  late final AnimationController _clockPulse;
  late final AnimationController _ambient;
  late final AnimationController _hover;
  late final AnimationController _morph;
  late final Listenable _repaint;

  late AnimatedHiblobRenderer _renderer;
  late core.Pose _fromPose;
  late core.Pose _toPose;
  late String _fromHead;
  late String _fromEye;
  late String _toHead;
  late String _toEye;
  bool _targetIsIdle = true;
  bool _hovered = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _clockPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: core.ambientRampMilliseconds,
      ),
    );
    _hover = AnimationController(vsync: this);
    _morph = AnimationController(vsync: this);
    _repaint = Listenable.merge([_clockPulse, _ambient, _hover, _morph]);
    _renderer = _makeRenderer(widget);
    _cutTo(widget.options.expression);
    _ambient.value =
        widget.active && widget.animation == HiblobAnimation.always ? 1 : 0;
    for (final AnimationController controller in [
      _ambient,
      _hover,
      _morph,
    ]) {
      controller.addStatusListener((AnimationStatus _) => _syncClock());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = widget.respectReducedMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _syncEnabledState(cut: true);
    } else {
      _syncClock();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedHiblob oldWidget) {
    super.didUpdateWidget(oldWidget);
    final core.HiblobOptions oldBase = _withoutExpression(oldWidget.options);
    final core.HiblobOptions newBase = _withoutExpression(widget.options);
    final bool identityChanged =
        oldWidget.name != widget.name || oldBase != newBase;

    if (identityChanged) {
      _renderer = _makeRenderer(widget);
      _cutTo(widget.options.expression);
    } else if (oldWidget.options.expression != widget.options.expression) {
      _morphTo(widget.options.expression);
    }

    final bool reduced = widget.respectReducedMotion &&
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final bool reducedChanged = reduced != _reducedMotion;
    _reducedMotion = reduced;
    if (identityChanged ||
        reducedChanged ||
        oldWidget.active != widget.active ||
        oldWidget.animation != widget.animation) {
      _syncEnabledState(cut: reducedChanged || !widget.active);
    } else {
      _syncClock();
    }
  }

  AnimatedHiblobRenderer _makeRenderer(AnimatedHiblob value) =>
      AnimatedHiblobRenderer(
        name: value.name,
        options: _withoutExpression(value.options),
      );

  void _cutTo(core.Expression? expression) {
    _morph.stop();
    _morph.value = 1;
    _toPose = expression?.pose ?? core.identityPose;
    _fromPose = _toPose;
    final core.Palette palette = _renderer.paletteFor(expression);
    _toHead = palette[core.colorHead]!;
    _toEye = palette[core.colorEye]!;
    _fromHead = _toHead;
    _fromEye = _toEye;
    _targetIsIdle = expression == null || expression == core.idle;
  }

  void _morphTo(core.Expression? expression) {
    if (_reducedMotion || !widget.active) {
      _cutTo(expression);
      return;
    }
    _fromPose = _currentPose;
    _fromHead = _currentHead;
    _fromEye = _currentEye;
    _toPose = expression?.pose ?? core.identityPose;
    final core.Palette palette = _renderer.paletteFor(expression);
    _toHead = palette[core.colorHead]!;
    _toEye = palette[core.colorEye]!;
    _targetIsIdle = expression == null || expression == core.idle;
    _morph.duration = Duration(
      milliseconds: _targetIsIdle
          ? core.expressionExitMilliseconds
          : core.expressionEnterMilliseconds,
    );
    _morph.forward(from: 0);
    _syncClock();
  }

  double get _morphProgress {
    final double value = _morph.value;
    return _targetIsIdle
        ? core.easeInOut(value)
        : core.expressionEnterEase(value);
  }

  core.Pose get _currentPose =>
      core.lerpPose(_fromPose, _toPose, _morphProgress);

  String get _currentHead => core.fadeHex(_fromHead, _toHead, _morphProgress);

  String get _currentEye => core.fadeHex(_fromEye, _toEye, _morphProgress);

  void _syncEnabledState({bool cut = false}) {
    if (_reducedMotion || !widget.active) {
      _clockPulse.stop();
      _ambient.stop();
      _hover.stop();
      if (cut) _cutTo(widget.options.expression);
      _ambient.value = 0;
      _hover.value = 0;
      return;
    }
    final double target =
        widget.animation == HiblobAnimation.always || _hovered ? 1 : 0;
    _ambient.animateTo(target, curve: _ambientCurve);
    _syncClock();
  }

  void _setHovered(bool value) {
    if (_hovered == value || _reducedMotion || !widget.active) return;
    _hovered = value;
    _hover.duration = Duration(
      milliseconds:
          value ? core.hoverEnterMilliseconds : core.hoverExitMilliseconds,
    );
    _hover.animateTo(value ? 1 : 0, curve: _hoverCurve);
    if (widget.animation == HiblobAnimation.hover) {
      _ambient.animateTo(value ? 1 : 0, curve: _ambientCurve);
    }
    _syncClock();
  }

  void _syncClock() {
    if (!mounted) return;
    final core.Pose pose = _currentPose;
    final bool needsClock = widget.active &&
        !_reducedMotion &&
        (widget.animation == HiblobAnimation.always ||
            _hovered ||
            _ambient.isAnimating ||
            _ambient.value > 0 ||
            _hover.isAnimating ||
            _morph.isAnimating ||
            pose.shake != 0 ||
            pose.rock != 0);
    if (needsClock && !_clockPulse.isAnimating) {
      _clockPulse.repeat();
    } else if (!needsClock && _clockPulse.isAnimating) {
      _clockPulse.stop();
    }
  }

  AnimatedHiblobFrame _frame() {
    final core.Pose pose = _currentPose;
    final double elapsed =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds /
            Duration.microsecondsPerMillisecond;
    final double amplitude = _ambient.value;
    return AnimatedHiblobFrame(
      motion: core.motionAt(
        _renderer.motionSeeds,
        elapsed,
        amplitude,
        shake: pose.shake,
      ),
      pose: pose,
      headColor: colorFromHex(_currentHead),
      eyeColor: colorFromHex(_currentEye),
      hover: _hover.value,
      amplitude: amplitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion || !widget.active) {
      return Hiblob(
        name: widget.name,
        size: widget.size,
        options: widget.options,
        semanticLabel: widget.semanticLabel,
      );
    }

    final AnimatedHiblobPainter painter = AnimatedHiblobPainter(
      renderer: _renderer,
      frameBuilder: _frame,
      repaint: _repaint,
    );
    final Widget figure;
    if (widget.size == null) {
      figure = SizedBox.expand(child: CustomPaint(painter: painter));
    } else {
      figure = SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: painter),
      );
    }
    return RepaintBoundary(
      child: Semantics(
        image: true,
        label: widget.semanticLabel,
        child: MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: figure,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clockPulse.dispose();
    _ambient.dispose();
    _hover.dispose();
    _morph.dispose();
    super.dispose();
  }
}

core.HiblobOptions _withoutExpression(core.HiblobOptions options) =>
    core.HiblobOptions(
      palette: options.palette,
      hue: options.hue,
      tone: options.tone,
      traits: options.traits,
      normalize: options.normalize,
      contrast: options.contrast,
      background: options.background,
    );
