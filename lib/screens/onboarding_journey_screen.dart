import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../widgets/dw_flame.dart';
import '../widgets/dw_svg.dart';
import '../widgets/onboarding_bits.dart';

/// Onboarding step 2 — "Every journey of faith is unique".
///
/// Pixel-faithful rebuild of the approved prototype's screen-journey
/// (quranic-onboarding-clone, 440×956 design space): warm paper canvas,
/// centred serif headline, an orange bloom over the candle-and-botanical
/// illustration, and the gradient Continue control — which this step pairs
/// with a circular back control that returns to step 1.
///
/// Total length of the arrival choreography, matching the grow screen's
/// intro so both onboarding steps share one rhythm.
const Duration _journeyIntroDuration = Duration(milliseconds: 2800);

/// The flame, measured inside the source art rather than on the artboard: the
/// sprite is the 72×145 patch at x 446–518, y 660–805 of the 974×1318
/// `faith-journey.png`, and the wick meets it at y=802. Keeping the numbers in
/// source pixels means they can be checked straight against the file.
const Size _faithJourneyArt = Size(974, 1318);
const Rect _faithJourneyBox = Rect.fromLTWH(9, 273, 422, 556);
const Rect _flameArtBox = Rect.fromLTRB(446, 660, 518, 805);

/// [_flameArtBox] mapped onto the 440×956 artboard.
///
/// The art renders object-fit: contain inside [_faithJourneyBox], so one scale
/// factor — plus the centring slack on whichever axis has room to spare — is
/// what turns a source-art rect into an artboard rect. Because the sprite is
/// scaled by that same factor and drawn with the same default filter as the art
/// underneath it, its pixels are exactly as soft as the ones they cover: the
/// join has nothing to give it away.
Rect _flameBox() {
  final scale = math.min(
    _faithJourneyBox.width / _faithJourneyArt.width,
    _faithJourneyBox.height / _faithJourneyArt.height,
  );
  final dx =
      _faithJourneyBox.left +
      (_faithJourneyBox.width - _faithJourneyArt.width * scale) / 2;
  final dy =
      _faithJourneyBox.top +
      (_faithJourneyBox.height - _faithJourneyArt.height * scale) / 2;
  return Rect.fromLTWH(
    dx + _flameArtBox.left * scale,
    dy + _flameArtBox.top * scale,
    _flameArtBox.width * scale,
    _flameArtBox.height * scale,
  );
}

class OnboardingJourneyScreen extends StatefulWidget {
  const OnboardingJourneyScreen({super.key});

  @override
  State<OnboardingJourneyScreen> createState() =>
      _OnboardingJourneyScreenState();
}

class _OnboardingJourneyScreenState extends State<OnboardingJourneyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    final still = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    _intro = AnimationController(vsync: this, duration: _journeyIntroDuration);
    if (still) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DwScreenFrame(
      background: Dw.onboardingPaper,
      designWidth: 440,
      designHeight: 956,
      body: (context) => Stack(
        children: [
          // .candle-art (z3) — hand holding a candle with botanical vines;
          // 974×1318 raster at 422px wide → 556px tall (object-fit:
          // contain). Shipped as a PNG because the traced SVG it replaced
          // held 62,272 paths (324,625 rectangles) and had to be compiled by
          // flutter_svg before it could paint — a ~1.3s stall on the UI
          // isolate in a debug build, with an empty hole where the art goes.
          // The box is named because the flame sprite below is placed from it.
          Positioned.fromRect(
            rect: _faithJourneyBox,
            child: const DwContainImage(
              'assets/09-onboarding/faith-journey.png',
            ),
          ),
          // .journey-flame (z3.1) — the same flame, cut out of the art above as
          // its own sprite and laid back over the spot it came from, so it can
          // flicker while the hand, the candle and the vines hold still. The
          // art keeps a soft candle-glow fill where the flame was, which is
          // what shows through when the sprite leans off its resting pose.
          Positioned.fromRect(rect: _flameBox(), child: const DwFlame()),
          // .journey-title (z4) — serif 46/1.02, centred, #076b5b. Same
          // blur-to-sharp resolve as the grow screen's headline.
          OnboardingBlurTitle(
            text: 'Every journey of\nfaith is unique',
            intro: _intro,
            left: 50,
            top: 124,
            width: 340,
            fontSize: 46,
            height: 1.02,
            letterSpacing: -0.75,
            color: Color(0xFF076B5B),
          ),
          // .journey-flower (z6) — bloom perched on the candle art.
          const Positioned(
            left: 197,
            top: 229,
            width: 47,
            height: 58,
            child: DwSvg('assets/09-onboarding/flower-orange.svg'),
          ),
          // Back to step 1. The disc pairs with the CTA on the same 57px
          // bottom row, so the CTA gives up the disc's width plus a 12px gap
          // (its right edge stays at 413, keeping the 27px side margins).
          OnboardingCircleBackButton(
            left: 27,
            top: 838,
            onTap: () =>
                Navigator.of(context)
                    .pushReplacementNamed(Routes.onboardingGrow),
          ),
          OnboardingContinueButton(
            label: 'Continue',
            left: 96, // 27 + 57 disc + 12 gap
            top: 838, // .screen-journey .continue-button — bottom: 61px
            width: 317, // 386 - 57 disc - 12 gap
            height: 57,
            onTap: () =>
                Navigator.of(context)
                    .pushReplacementNamed(Routes.onboardingQuranic),
          ),
        ],
      ),
    );
  }
}

/// The prototype's `.journey-title`: 46px serif, centred, two lines — the
/// [OnboardingBlurTitle] handles the blur-to-sharp arrival.
