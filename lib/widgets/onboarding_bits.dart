import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'dw_svg.dart';

/// Emblem shown top-left on the three onboarding screens.
class OnboardingEmblem extends StatelessWidget {
  const OnboardingEmblem({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 31,
      top: 100,
      width: 44,
      height: 44,
      child: DwSvg('assets/02-onboarding-read/emblem-forest.svg'),
    );
  }
}

/// 35px serif headline, one array entry per approved line break.
class OnboardingTitle extends StatelessWidget {
  const OnboardingTitle(this.lines, {super.key});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 30,
      right: 28,
      top: 165,
      child: Text(
        lines.join('\n'),
        style: const TextStyle(
          fontSize: 35,
          height: 1.20,
          letterSpacing: -1.5,
          color: Dw.forest,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

/// 18px supporting paragraph, one array entry per approved line break.
class OnboardingLead extends StatelessWidget {
  const OnboardingLead(this.lines, {super.key, required this.top});

  final List<String> lines;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 31,
      right: 28,
      top: top,
      child: Text(
        lines.join('\n'),
        style: const TextStyle(
          fontSize: 18,
          height: 1.42,
          letterSpacing: -0.35,
          color: Dw.secondary,
        ),
      ),
    );
  }
}

/// Step indicator (`dots.svg`, 56x14) centered horizontally.
///
/// Each step ships its own `dots.svg` with the active dot
/// (step 1 → `02-onboarding-read`, step 2 → `03-onboarding-listen`,
/// step 3 → `04-onboarding-translation`).
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.asset, required this.top});

  final String asset;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (Dw.designWidth - 56) / 2,
      top: top,
      width: 56,
      height: 14,
      child: DwSvg(asset),
    );
  }
}

/// Sage pill call-to-action.
class CtaButton extends StatelessWidget {
  const CtaButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.left,
  });

  final String label;
  final VoidCallback onTap;
  final double left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: 29,
      top: 705,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Dw.sage,
              borderRadius: BorderRadius.circular(31),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, color: Dw.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// 60px circular back control on steps 2 and 3.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 29,
      top: 705,
      width: 60,
      height: 60,
      child: Semantics(
        button: true,
        label: 'Back',
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Dw.back,
            ),
            child: Center(child: DwSvg(asset, width: 24, height: 24)),
          ),
        ),
      ),
    );
  }
}
