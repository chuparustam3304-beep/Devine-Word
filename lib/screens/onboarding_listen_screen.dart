import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../widgets/onboarding_bits.dart';

/// Screen 03 — onboarding step 2: listening.
class OnboardingListenScreen extends StatelessWidget {
  const OnboardingListenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DwScreenFrame(
      background: Dw.canvas,
      body: (context) => Stack(
        children: [
          const OnboardingEmblem(
            asset: 'assets/03-onboarding-listen/emblem-forest.svg',
          ),
          const OnboardingTitle(['Listen.', 'Reflect.', 'Understand.']),
          const OnboardingLead([
            'Hear each ayah in Arabic,',
            'then listen to its translation.',
          ], top: 304),
          // Headphones illustration with the two-step playback order.
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
                  Image.asset(
                    'assets/03-onboarding-listen/onboarding-headphones.png',
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 17,
                    top: 70,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stepRow('01', 'Arabic recitation'),
                        Container(
                          width: 1,
                          height: 30,
                          margin: const EdgeInsets.only(left: 14.5),
                          color: Dw.green,
                        ),
                        _stepRow('02', 'Your translation'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const StepDots(
            asset: 'assets/03-onboarding-listen/dots.svg',
            top: 652,
          ),
          BackCircleButton(
            asset: 'assets/03-onboarding-listen/arrow-left.svg',
            onTap: () =>
                Navigator.of(context)
                    .pushReplacementNamed(Routes.onboardingRead),
          ),
          CtaButton(
            label: 'Continue',
            left: 96,
            onTap: () =>
                Navigator.of(context)
                    .pushReplacementNamed(Routes.onboardingTranslation),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String number, String label) {
    return SizedBox(
      height: 31,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Dw.green,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 12, color: Dw.white),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Dw.forest,
            ),
          ),
        ],
      ),
    );
  }
}
