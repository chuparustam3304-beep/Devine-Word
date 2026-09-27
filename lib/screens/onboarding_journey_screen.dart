import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
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

/// Headline: opacity resolves over this slice, the blur clears over
/// [_journeyTitleBlur]. The two are deliberately offset, so the type is
/// already legible while it is still finishing its defocus — same recipe
/// as the grow screen's title.
const Interval _journeyTitleFade = Interval(0.10, 0.45, curve: Curves.easeOut);
const Interval _journeyTitleBlur = Interval(0.00, 0.62, curve: Curves.easeOut);

/// Blur radius (design px) the headline starts at.
const double _journeyTitleBlurStart = 12;

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
          // 974×1318 vector source at 422px wide → 556px tall
          // (object-fit: contain).
          Positioned(
            left: 9,
            top: 273,
            width: 422,
            height: 556,
            child: const DwSvg('assets/09-onboarding/faith-journey.svg'),
          ),
          // .journey-title (z4) — serif 46/1.02, centred, #076b5b. Same
          // blur-to-sharp resolve as the grow screen's headline.
          _JourneyTitle(intro: _intro),
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

/// The prototype's `.journey-title`: 46px serif, centred, two lines. It
/// never moves — it resolves from a heavy blur into sharp type, the same
/// choreography as the grow screen's headline.
class _JourneyTitle extends StatelessWidget {
  const _JourneyTitle({required this.intro});

  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 50,
      top: 124,
      width: 340,
      child: AnimatedBuilder(
        animation: intro,
        builder: (context, child) {
          final opacity = _journeyTitleFade.transform(intro.value);
          final sharpen = _journeyTitleBlur.transform(intro.value);
          final sigma = _journeyTitleBlurStart * (1 - sharpen);
          final text = Opacity(opacity: opacity, child: child!);
          if (sigma < 0.05) return text;
          return ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: text,
          );
        },
        child: const Text(
          'Every journey of\nfaith is unique',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Dw.display,
            fontSize: 46,
            height: 1.02,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.75,
                        color: Color(0xFF076B5B),
          ),
        ),
      ),
    );
  }
}
