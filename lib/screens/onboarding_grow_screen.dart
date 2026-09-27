import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../widgets/dw_svg.dart';
import '../widgets/onboarding_bits.dart';

/// Total length of the arrival choreography; every window below is a slice
/// of it.
const Duration _growIntroDuration = Duration(milliseconds: 2800);

/// Massif: it climbs in from under the bottom edge as the opening beat, so
/// the ground is already solid before the headline resolves or the leaf
/// falls. `easeOutQuad` rather than `easeOutCubic` — the cubic threw ~44% of
/// the travel into the first 140ms, which read as a pop; the quad spreads it
/// out so the whole range is seen to slide.
const Interval _growMountainRise = Interval(
  0.00,
  0.32,
  curve: Curves.easeOutQuad,
);

/// How far below its seat the massif starts, in design px. One full box
/// height, so the summit itself begins under the bottom edge and the whole
/// range has to climb into view.
const double _growMountainRiseFrom = 956 - Dw.mountainTop;

/// Headline: opacity resolves over this slice, the blur clears over
/// [_growTitleBlur]. The two are deliberately offset, so the type is already
/// legible while it is still finishing its defocus.
const Interval _growTitleFade = Interval(0.10, 0.45, curve: Curves.easeOut);
const Interval _growTitleBlur = Interval(0.00, 0.62, curve: Curves.easeOut);

/// Blur radius (design px) the headline starts at.
const double _growTitleBlurStart = 12;

/// Leaf: it leaves the top of the frame at 0.65 — after the headline has
/// settled — and is seated by 1.00.
const Interval _growLeafDrop = Interval(0.65, 1.00, curve: Curves.easeOutCubic);

/// Leaf fade-in, as a fraction of the drop. The leaf is still above the
/// frame for roughly the first 0.07 of the drop, so this has already
/// finished by the time its first pixel peeks in — it exists to soften that
/// first sliver rather than to make the leaf translucent as it lands.
const double _growLeafFade = 0.10;

/// How far above its seat the leaf starts, in design px. Large enough that
/// it begins off-screen, so it really reads as falling in from the top.
const double _growLeafStartDrop = 180;

/// Sideways sway while falling, in design px. A falling leaf never tracks a
/// straight line; the sway dies out to zero as it lands.
const double _growLeafSway = 16;

/// Full turns the leaf makes while falling. A whole number, so the last
/// frame lands square on the leaf's seat (rotation back to 0).
const double _growLeafTurns = 1;

/// Blooms: they fade in over this slice and then turn forever.
const Interval _growBloomFade = Interval(0.70, 0.88, curve: Curves.easeOut);

/// Screen 01 — onboarding step 1: "Grow closer to GOD a little more
/// everyday".
///
/// Pixel-faithful rebuild of the approved prototype's `.screen-grow`
/// (quranic-onboarding-clone, 440×956 design space): the deep-green canvas,
/// the massif anchored on [Dw.mountainTop] and running off the bottom edge,
/// the two frosted feature pills, and the single full-width Continue CTA —
/// which sits on the mountain itself rather than on a cream shelf.
///
/// The prototype is static; this screen adds a four-beat arrival so the step
/// feels alive when it lands, then holds perfectly still:
///
///  1. the massif slides up out of the bottom edge into its seat — the
///     opening beat, so the ground is solid before anything else moves;
///  2. the headline never moves — it resolves out of a heavy blur into sharp
///     white type exactly where the reference puts it;
///  3. once it is legible, the orange leaf tumbles in from above the frame —
///     painting behind the headline — and settles into the slot the
///     reference gives it (157, 114);
///  4. the two yellow blooms fade in and then rotate forever, very slowly,
///     and never stop.
///
/// Under `prefers-reduced-motion` the intro is skipped entirely: the first
/// frame is already the settled screen.
class OnboardingGrowScreen extends StatefulWidget {
  const OnboardingGrowScreen({super.key});

  @override
  State<OnboardingGrowScreen> createState() => _OnboardingGrowScreenState();
}

class _OnboardingGrowScreenState extends State<OnboardingGrowScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _bloomSpinA;
  late final AnimationController _bloomSpinB;

  @override
  void initState() {
    super.initState();
    final still = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    _intro = AnimationController(vsync: this, duration: _growIntroDuration);
    if (still) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }

    // "Very slowly": one full turn every 12s / 15s. The bloom carries a
    // five-fold symmetry, so a turn reads as a gentle drift rather than a
    // spin — but it is continuous and never settles.
    _bloomSpinA = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _bloomSpinB = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (!still) {
      _bloomSpinA.repeat();
      _bloomSpinB.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _bloomSpinA.dispose();
    _bloomSpinB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DwScreenFrame(
      background: Dw.onboardingDeepGreen,
      designWidth: 440,
      designHeight: 956,
      body: (context) => Stack(
        children: [
          // .mountain-art (z3) — a 737×455 source scaled to *cover* the whole
          // 554 → bottom band, so the massif runs off the bottom edge and the
          // Continue CTA sits on the mountain itself. Cover (rather than
          // fitWidth) keeps the slopes undistorted; it costs the outer flanks,
          // which crop away at the sides.
          Positioned(
            left: 0,
            top: Dw.mountainTop,
            width: 440,
            height: 956 - Dw.mountainTop,
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, child) => Transform.translate(
                // Climbs in from one box-height below, so the range rises out
                // of the bottom edge and seats exactly on .mountain-art's line.
                // At the end of the window the eased value is 1.0, so the
                // settled offset is a hard zero rather than a near-miss.
                offset: Offset(
                  0,
                  _growMountainRiseFrom *
                      (1 - _growMountainRise.transform(_intro.value)),
                ),
                child: child,
              ),
              child: Image.asset(
                'assets/09-onboarding/mountain.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          // .top-leaf (z6) — deliberately before `.grow-title` (z7), so the
          // leaf falls behind the headline.
          _GrowLeaf(intro: _intro),
          _GrowTitle(intro: _intro),
          // .flower-right / .flower-left — the reference nests them inside
          // `.grow-title`'s spans, so they paint with the title (z7).
          _SpinningBloom(intro: _intro, spin: _bloomSpinA, left: 360, top: 253),
          _SpinningBloom(intro: _intro, spin: _bloomSpinB, left: 42, top: 387),
          // .feature-pill (z8).
          const OnboardingFeaturePill(
            icon: 'assets/09-onboarding/headphones.svg',
            label: 'Audio devotionals',
            top: 151,
            right: 53,
          ),
          const OnboardingFeaturePill(
            icon: 'assets/09-onboarding/drop.svg',
            label: 'Private reflections',
            top: 510,
            left: 59,
          ),
          // .grow-button — left 35 / width 370 / height 60 / bottom 63.
          OnboardingContinueButton(
            label: 'Continue',
            left: 35,
            top: 833,
            width: 370,
            height: 60,
            radius: 30,
            onTap: () => Navigator.of(
              context,
            ).pushReplacementNamed(Routes.onboardingJourney),
          ),
        ],
      ),
    );
  }
}

/// The prototype's `.top-leaf`: an orange leaf that tumbles in from above the
/// frame — behind the headline — and lands squarely in the slot the reference
/// gives it (157, 114).
class _GrowLeaf extends StatelessWidget {
  const _GrowLeaf({required this.intro});

  final Animation<double> intro;

  /// `.top-leaf` is 49px wide; `leaf-orange.svg` is an 82×70 viewBox.
  static const double _width = 49;
  static const double _height = _width * 70 / 82;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 157,
      top: 114,
      width: _width,
      height: _height,
      child: AnimatedBuilder(
        animation: intro,
        builder: (context, child) {
          final drop = _growLeafDrop.transform(intro.value);
          final opacity = Curves.easeOut.transform(
            (drop / _growLeafFade).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              // Falls in from above; the sideways sway dies out on landing.
              offset: Offset(
                math.sin(drop * math.pi) * _growLeafSway * (1 - drop),
                -_growLeafStartDrop * (1 - drop),
              ),
              child: Transform.rotate(
                // `% 1` keeps whole turns landing at exactly 0deg, so the
                // settled leaf measures its true 49×41.8 box.
                angle: 2 * math.pi * ((_growLeafTurns * drop) % 1.0),
                child: child,
              ),
            ),
          );
        },
        child: const DwSvg('assets/09-onboarding/leaf-orange.svg'),
      ),
    );
  }
}

/// The prototype's `.grow-title`: 62px serif, centred, four lines. It never
/// moves — it resolves from a heavy blur into sharp type.
class _GrowTitle extends StatelessWidget {
  const _GrowTitle({required this.intro});

  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 38,
      top: 185,
      width: 364,
      child: AnimatedBuilder(
        animation: intro,
        builder: (context, child) {
          final opacity = _growTitleFade.transform(intro.value);
          final sharpen = _growTitleBlur.transform(intro.value);
          final sigma = _growTitleBlurStart * (1 - sharpen);
          final text = Opacity(opacity: opacity, child: child!);
          if (sigma < 0.05) return text;
          return ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: text,
          );
        },
        child: const Text(
          'Grow closer\nto GOD\na little more\neveryday',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Dw.display,
            fontSize: 62,
            height: 1.05,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.8,
            color: Dw.white,
          ),
        ),
      ),
    );
  }
}

/// `.flower-right` / `.flower-left`: a yellow bloom that fades in and then
/// turns forever, very slowly.
class _SpinningBloom extends StatelessWidget {
  const _SpinningBloom({
    required this.intro,
    required this.spin,
    required this.left,
    required this.top,
  });

  final Animation<double> intro;
  final Animation<double> spin;
  final double left;
  final double top;

  /// `.grow-title .flower` — 42×42.
  static const double _size = 42;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: _size,
      height: _size,
      child: AnimatedBuilder(
        // The bloom keeps turning long after the intro is over, so the
        // rotation listens to [spin]; rebuilding off [intro] alone would
        // freeze it on the intro's last frame.
        animation: spin,
        builder: (context, child) =>
            Transform.rotate(angle: spin.value * 2 * math.pi, child: child),
        child: AnimatedBuilder(
          animation: intro,
          builder: (context, child) => Opacity(
            opacity: _growBloomFade.transform(intro.value),
            child: child,
          ),
          child: const DwSvg('assets/09-onboarding/flower-yellow.svg'),
        ),
      ),
    );
  }
}
