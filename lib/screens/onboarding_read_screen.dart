import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../widgets/dw_blend_image.dart';
import '../widgets/onboarding_bits.dart';

/// Screen 02 — onboarding step 1: reading.
class OnboardingReadScreen extends StatelessWidget {
  const OnboardingReadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DwScreenFrame(
      background: Dw.canvas,
      body: (context) => Stack(
        children: [
          const OnboardingEmblem(
            asset: 'assets/02-onboarding-read/emblem-forest.svg',
          ),
          const OnboardingTitle(['A closer', 'connection to', 'the Quran']),
          const OnboardingLead([
            'Read, listen, and reflect —',
            'anytime, anywhere.',
          ], top: 302),
          // Illustration card with the approved 13:28 reflection.
          Positioned(
            left: 29,
            right: 29,
            top: 391,
            height: 208,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The HTML `.art-card` is transparent, so the screen
                  // canvas is the card's base.
                  const ColoredBox(color: Dw.canvas),
                  // Outermost layer: the same green family as the artwork's
                  // inner panel at low opacity. 13% resolves to the approved
                  // reference's outer tone (238, 243, 234) over the canvas.
                  ColoredBox(color: Dw.green.withValues(alpha: 0.13)),
                  // The mosque artwork composites with a canvas-level
                  // `darken` so its opaque white surround resolves onto the
                  // tinted base exactly as in the approved reference, while
                  // the deeper artwork keeps its own color.
                  DwBlendImage(
                    asset: 'assets/02-onboarding-read/onboarding-mosque.png',
                    blendMode: BlendMode.darken,
                  ),
                  Positioned(
                    left: 23,
                    bottom: 22,
                    right: 23,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '“Verily, in the remembrance\nof Allah do hearts find rest.”',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: Dw.secondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '— Qur’an 13:28',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: Dw.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const StepDots(
            asset: 'assets/02-onboarding-read/dots.svg',
            top: 652,
          ),
          CtaButton(
            label: 'Get Started',
            left: 28,
            onTap: () =>
                Navigator.of(context)
                    .pushReplacementNamed(Routes.onboardingListen),
          ),
        ],
      ),
    );
  }
}
