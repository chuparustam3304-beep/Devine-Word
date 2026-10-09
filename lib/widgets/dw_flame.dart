import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How long the flame takes to draw once: it stretches tall and thin, then
/// settles back onto the wick.
const Duration _breathPeriod = Duration(milliseconds: 2879);

/// The quick jitter of the tip. Both this and [_breathPeriod] are prime
/// millisecond counts, so the two loops only realign after
/// 2,879 × 811 ms ≈ 39 minutes and the flicker never resolves into a visible
/// cycle. (The grow screen takes the same approach with its 12s/15s turns.)
const Duration _flutterPeriod = Duration(milliseconds: 811);

const double _twoPi = 2 * math.pi;

/// The candle flame from `faith-journey.png`, cut out as its own sprite so it
/// can move while the rest of the artwork holds still.
///
/// A candle is the one thing in the onboarding art that is *not* still, and the
/// flame is where the scene gets its warmth, so it leans and stretches around
/// the point where it meets the wick — never around its own middle, which would
/// slide the base sideways and give the trick away. Two loops drive it: the slow
/// draw ([_breathPeriod]) that mostly governs height and brightness, and the
/// fast flutter ([_flutterPeriod]) that mostly governs the lean. Because they
/// are incommensurate the tip traces a path that never repeats.
///
/// The sprite is painted exactly where the flame already sits in the artwork,
/// and the art keeps a soft candle-glow fill underneath it (the sprite pasted
/// back at rest reproduces the original art to 0.07/255 mean channel error), so
/// the only pixels that change from frame to frame are the flame's own. When the
/// platform asks for animations to be turned off, the sprite is simply drawn in
/// place — still the same picture.
class DwFlame extends StatefulWidget {
  const DwFlame({super.key});

  @override
  State<DwFlame> createState() => _DwFlameState();
}

class _DwFlameState extends State<DwFlame> with TickerProviderStateMixin {
  /// The sprite's 72×145 box ends at art y=805 while the wick meets the flame
  /// at y=802, so the pivot sits 0.979 of the way down: below it, the sliver of
  /// wick that the sprite also carries is hidden behind the candle, and pinning
  /// the transform there keeps it hidden while the flame sways.
  static const double _pivot = 0.979;

  late final AnimationController _breath;
  late final AnimationController _flutter;

  @override
  void initState() {
    super.initState();
    final still = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    _breath = AnimationController(vsync: this, duration: _breathPeriod);
    _flutter = AnimationController(vsync: this, duration: _flutterPeriod);
    if (!still) {
      _breath.repeat();
      _flutter.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _flutter.dispose();
    super.dispose();
  }

  /// One frame's worth of motion.
  ///
  /// A candle flame is never quite symmetrical in time: it snaps back as it
  /// collapses. The flutter is therefore a sine plus a little second harmonic
  /// rather than a clean arc, and the lean stays a weighted mix of both loops
  /// so the tip does not travel the same line on every sway.
  ({double lean, double stretch}) get _pose {
    final phase = _twoPi * _flutter.value;
    final flutter = (math.sin(phase) + 0.35 * math.sin(2 * phase + 1.7)) / 1.35;
    final breath = math.sin(_twoPi * _breath.value);
    return (
      lean: (0.62 * breath + 0.38 * flutter) * 0.052,
      stretch: 0.036 * breath + 0.010 * flutter,
    );
  }

  @override
  Widget build(BuildContext context) {
    const sprite = Image(
      image: AssetImage('assets/09-onboarding/candle-flame.png'),
      fit: BoxFit.fill,
      gaplessPlayback: true,
    );
    // Reduce Motion: the illustration as approved, holding its own light.
    if (!_breath.isAnimating && !_flutter.isAnimating) {
      return sprite;
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_breath, _flutter]),
        child: sprite,
        builder: (context, child) {
          final (:lean, :stretch) = _pose;
          // Stretch before leaning, so the flame grows along its own axis and
          // only then tips over — scaling after the rotation would shear it.
          // Sideways it pinches as it draws up, the way a real flame does.
          final matrix = Matrix4.identity()
            ..rotateZ(lean)
            ..scaleByDouble(1 - 0.55 * stretch, 1 + stretch, 1, 1);
          return Transform(
            // Anchor at the wick, never the box's middle.
            alignment: const Alignment(0, 2 * _pivot - 1),
            transform: matrix,
            child: Opacity(
              // Brightest at the top of the draw, dimmest as it settles back.
              opacity:
                  0.945 +
                  0.055 * (0.5 + 0.5 * math.sin(_twoPi * _breath.value)),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
