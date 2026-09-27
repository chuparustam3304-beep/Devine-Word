import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'dw_svg.dart';

/// Gradient call-to-action shared by the three quranic onboarding screens.
///
/// Rebuilds the prototype's `.continue-button`: a 90° gradient from
/// `#066859` to `#086e60`, white 18px label. Geometry differs per screen
/// (`.screen-journey .continue-button`, `.grow-button`, `.quran-button`)
/// and is passed in; all geometry lives in the prototype's 440×956
/// design space.
class OnboardingContinueButton extends StatelessWidget {
  const OnboardingContinueButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.radius = 29,
  });

  final String label;
  final VoidCallback onTap;
  final double left;
  final double top;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF066859), Color(0xFF086E60)],
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.25,
                color: Dw.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular back control for the onboarding steps that can go back.
///
/// Reuses the design pack's `back-arrow.svg` — a pale `#DDEBE1` disc with a
/// green arrow — at [size] px. The delivered glyph sat 3.7 units right of the
/// disc's centre (x 17.6..37.8 in the 48-unit viewBox) and read large, so it
/// is re-centred and cut to 18.6/48 units in the asset itself; that keeps
/// every step's disc identical. Against the paper canvas (`#f5eedf`) the disc
/// reads as a subtly different fill without competing with the Continue CTA,
/// which is why it is paired with one on the same bottom row.
class OnboardingCircleBackButton extends StatelessWidget {
  const OnboardingCircleBackButton({
    super.key,
    required this.left,
    required this.top,
    required this.onTap,
    this.size = 57,
    this.semanticLabel = 'Back',
  });

  final double left;
  final double top;
  final VoidCallback onTap;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const DwSvg('assets/09-onboarding/back-arrow.svg'),
        ),
      ),
    );
  }
}

/// Frosted feature pill floating over the deep-green grow screen
/// (`.feature-pill` — 30px tall, 16px radius, 14px icon + 12.5px label).
/// Anchored by [left] or [right]; one of the two must be provided.
class OnboardingFeaturePill extends StatelessWidget {
  const OnboardingFeaturePill({
    super.key,
    required this.icon,
    required this.label,
    required this.top,
    this.left,
    this.right,
  }) : assert(left != null || right != null);

  final String icon;
  final String label;
  final double top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      height: 30,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          // rgba(0, 38, 34, .30)
          color: const Color(0xFF002622).withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DwSvg(icon, width: 14, height: 14),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.12,
                color: Dw.white.withValues(alpha: 0.94),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
