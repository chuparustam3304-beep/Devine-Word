import 'package:flutter/material.dart';

import '../data/models.dart';
import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../state/app_state_scope.dart';
import '../widgets/dw_svg.dart';
import '../widgets/onboarding_bits.dart';

/// Screen 04 — onboarding step 3: translation language selection.
class OnboardingTranslationScreen extends StatelessWidget {
  const OnboardingTranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return DwScreenFrame(
      background: Dw.canvas,
      body: (context) => Stack(
        children: [
          const OnboardingEmblem(
            asset: 'assets/04-onboarding-translation/emblem-forest.svg',
          ),
          const OnboardingTitle(['A meaning', 'closer to', 'you.']),
          const OnboardingLead([
            'Arabic stays. Choose your',
            'preferred translation.',
          ], top: 303),
          // Language choice panel. Selection persists via AppState.
          Positioned(
            left: 29,
            right: 29,
            top: 390,
            child: Container(
              height: 197,
              decoration: BoxDecoration(
                color: Dw.pale.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                children: [
                  // Each row expands to exactly one third of the 197px
                  // card, so the fixed row heights can never overflow
                  // the container's bottom edge.
                  for (final (index, language)
                      in TranslationLanguage.values.indexed)
                    Expanded(
                      child: _languageRow(
                        language: language,
                        selected: state.translation == language,
                        showDivider:
                            index != TranslationLanguage.values.length - 1,
                        onTap: () => state.setTranslation(language),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 31,
            top: 605,
            child: Text(
              'You can change this in Settings.',
              style: TextStyle(fontSize: 12, color: Dw.muted),
            ),
          ),
          const StepDots(
            asset: 'assets/04-onboarding-translation/dots.svg',
            top: 657,
          ),
          BackCircleButton(
            asset: 'assets/04-onboarding-translation/arrow-left.svg',
            onTap: () =>
                Navigator.of(context)
                    .pushReplacementNamed(Routes.onboardingListen),
          ),
          CtaButton(
            label: 'Start reading',
            left: 96,
            onTap: () async {
              await state.completeOnboarding();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(Routes.home, (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _languageRow({
    required TranslationLanguage language,
    required bool selected,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    final TextStyle strongStyle = switch (language) {
      TranslationLanguage.urdu => const TextStyle(
        fontFamily: Dw.urdu,
        fontSize: 25,
        height: 1,
        fontWeight: FontWeight.w500,
      ),
      TranslationLanguage.bengali => const TextStyle(
        fontFamily: Dw.bengali,
        fontSize: 23,
        fontWeight: FontWeight.w500,
      ),
      TranslationLanguage.english => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: 'Translation language ${language.label}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // Height comes from the Expanded parent (197 / 3) so the
          // rows can never overflow the card's bottom edge.
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: showDivider
                    ? Dw.forest.withValues(alpha: 0.11)
                    : const Color(0x00000000),
              ),
            ),
          ),
          child: Row(
            children: [
              DwSvg(
                selected
                    ? 'assets/04-onboarding-translation/radio-selected.svg'
                    : 'assets/04-onboarding-translation/radio-unselected.svg',
                width: 27,
                height: 27,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  language.label,
                  style: const TextStyle(fontSize: 16, color: Dw.forest),
                ),
              ),
              Text(language.nativeLabel, style: strongStyle),
            ],
          ),
        ),
      ),
    );
  }
}
