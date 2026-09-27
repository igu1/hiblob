/// Facial expressions: poses drawn on top of the hiblob body.
///
/// An [Expression] shifts the eyes ([eyeOffsetDx], [eyeOffsetDy]) and may
/// tint the body toward a color. The eye *shapes* each expression draws are
/// chosen by the layout when it builds the eye marks.
library;

/// One expression pose.
class Expression {
  /// Stable identifier, e.g. `'happy'`.
  final String id;

  /// Fixed eye shift in view-box units (negative x looks left, negative y
  /// looks up).
  final double eyeOffsetDx;
  final double eyeOffsetDy;

  /// Body tint as ARGB, blended by [tintAlpha]. `null` means no tint.
  final int? tint;
  final double tintAlpha;

  const Expression(
    this.id, {
    this.eyeOffsetDx = 0,
    this.eyeOffsetDy = 0,
    this.tint,
    this.tintAlpha = 0,
  });

  @override
  bool operator ==(Object other) => other is Expression && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Expression($id)';
}

/// The neutral face.
const Expression idle = Expression('idle');

/// Closed smiling eyes.
const Expression happy = Expression('happy');

/// Eyes curved upward at the outer edge.
const Expression sad = Expression('sad');

/// Slanted, lowered brows with a faint hot tint.
const Expression mad = Expression(
  'mad',
  tintAlpha: 0.10,
);

/// Wide round eyes.
const Expression surprised = Expression('surprised');

/// One eye open, one closed.
const Expression wink = Expression('wink');

/// Half-closed, drooping eyes.
const Expression sleepy = Expression('sleepy');

/// One eye open, one raised in a smirk.
const Expression smug = Expression('smug');

/// One eye open, one small and doubtful.
const Expression unsure = Expression('unsure');

/// Widest eyes with a faint cold tint.
const Expression scared = Expression(
  'scared',
  tintAlpha: 0.10,
);

/// Heart-shaped eyes with a warm tint.
const Expression love = Expression(
  'love',
  tintAlpha: 0.22,
);

/// Small closed eyes drawn inward, blushing.
const Expression shy = Expression(
  'shy',
  tintAlpha: 0.15,
);

/// Squinting lines with a queasy tint.
const Expression sick = Expression(
  'sick',
  tintAlpha: 0.18,
);

/// Eyes glancing up and to the left, one squinting.
const Expression thinking = Expression(
  'thinking',
  eyeOffsetDx: -1.2,
  eyeOffsetDy: -1.6,
);

/// A wide open smile.
const Expression grin = Expression('grin');

/// A downturned mouth that droops at the corners.
const Expression frown = Expression('frown');

/// Every built-in expression, in roster order.
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
  grin,
  frown,
];

/// The tint color used by expressions that carry one, as ARGB.
int tintFor(Expression expression) {
  switch (expression.id) {
    case 'love':
      return 0xFFF06292; // warm pink
    case 'shy':
      return 0xFFF8BBD0; // blush
    case 'sick':
      return 0xFF9CCC65; // queasy green
    case 'scared':
      return 0xFF90CAF9; // cold blue
    case 'mad':
      return 0xFFEF5350; // hot red
    default:
      return 0x00000000;
  }
}
