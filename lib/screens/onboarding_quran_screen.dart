import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../state/app_state_scope.dart';
import '../widgets/dw_svg.dart';
import '../widgets/onboarding_bits.dart';

/// Onboarding screen 3 — "Everyday a new Quranic Ayah with Recitation &
/// Translation".
///
/// Pixel-faithful rebuild of the approved prototype's screen-quran
/// (quranic-onboarding-clone, 440×956 design space): a soft glass panel
/// framing the serif headline, the gold moon separator, four real ayah
/// rows with rosette verse numbers and book badges. Continue completes
/// onboarding and opens home.
///
/// One deliberate departure from the prototype: its `.back-button` floats
/// bare at the top-left, so this step pairs the pale circular back disc with
/// the Continue CTA on the bottom row instead — the same control and row
/// geometry as step 2.
///
/// The prototype's in-screen iOS status-bar mock is not reproduced: the
/// real system status bar occupies that region on device (the same
/// convention as every other screen in this app).
class OnboardingQuranScreen extends StatelessWidget {
  const OnboardingQuranScreen({super.key});

  /// The four approved rows, in order. Arabic sizes are the prototype's
  /// per-row adjustments (`.ayah-row:nth-child(n) .ayah-arabic`).
  static const List<_AyahRowData> _rows = [
    _AyahRowData(
      arabic: 'اقْرَأْ بِاسْمِ رَبِّكَ الَّذِي خَلَقَ',
      meta: 'سورة العلق  –  1',
      number: '١',
      arabicSize: 23.5,
    ),
    _AyahRowData(
      arabic: 'وَمَا خَلَقْتُ الْجِنَّ وَالْإِنسَ إِلَّا لِيَعْبُدُونِ',
      meta: 'سورة الذاريات  –  56',
      number: '٥٦',
      arabicSize: 22.2,
    ),
    _AyahRowData(
      arabic: 'إِنَّ هَٰذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ',
      meta: 'سورة الإسراء  –  9',
      number: '٩',
      arabicSize: 22.3,
    ),
    _AyahRowData(
      arabic: 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      meta: 'سورة طه  –  114',
      number: '١١٤',
      arabicSize: 25,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return DwScreenFrame(
      background: Dw.onboardingPaper,
      designWidth: 440,
      designHeight: 956,
      body: (context) => Stack(
        children: [
          // .quran-panel (z1) — inset glass frame.
          Positioned(
            left: 20,
            right: 20,
            top: 33,
            bottom: 27,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                color: Dw.white.withValues(alpha: 0.085),
                border: Border.all(color: Dw.white.withValues(alpha: 0.12)),
              ),
            ),
          ),
          // .quran-title (z6) — serif 33.5/1.09, centred, #066a5a.
          const Positioned(
            left: 45,
            top: 149,
            width: 350,
            child: Text(
              'Everyday a new\nQuranic Ayah with\nRecitation & Translation',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Dw.display,
                fontSize: 33.5,
                height: 1.09,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.45,
                color: Color(0xFF066A5A),
              ),
            ),
          ),
          // .moon-separator (z6) — 37px gold rules around the moon.
          Positioned(
            left: 150,
            top: 287,
            width: 140,
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 37, height: 1, color: Dw.onboardingGold),
                const DwSvg(
                  'assets/09-onboarding/moon.svg',
                  width: 48,
                  height: 34,
                ),
                Container(width: 37, height: 1, color: Dw.onboardingGold),
              ],
            ),
          ),
          // .ayah-list (z8) — rows 77px tall separated by 27px gaps.
          Positioned(
            left: 38,
            right: 31,
            top: 357,
            child: Column(
              children: [
                for (final (index, row) in _rows.indexed) ...[
                  if (index > 0) const SizedBox(height: 27),
                  _AyahRow(data: row),
                ],
              ],
            ),
          ),
          // Back control. The prototype floats `.back-button` at the top-left
          // (38, 98); the rebuilt flow instead mirrors step 2 and pairs the
          // pale disc with the CTA on the bottom row, anchored to that row's
          // left edge at 27. The CTA keeps the prototype's right edge at 393
          // (.quran-button: 47 + 346), giving up the 55px disc plus a 12px gap.
          OnboardingCircleBackButton(
            left: 27,
            top: 815, // .quran-button — bottom: 86px
            size: 55,
            onTap: () =>
                Navigator.of(context)
                    .pushReplacementNamed(Routes.onboardingJourney),
          ),
          OnboardingContinueButton(
            label: 'Continue',
            left: 94, // 27 + 55 disc + 12 gap
            top: 815, // .quran-button — bottom: 86px
            width: 299, // 346 - 55 disc - 12 gap
            height: 55,
            radius: 28,
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
}

/// One approved row of the `.ayah-list`.
class _AyahRowData {
  const _AyahRowData({
    required this.arabic,
    required this.meta,
    required this.number,
    required this.arabicSize,
  });

  final String arabic;
  final String meta;
  final String number;
  final double arabicSize;
}

class _AyahRow extends StatelessWidget {
  const _AyahRow({required this.data});

  final _AyahRowData data;

  @override
  Widget build(BuildContext context) {
    // Grid: `minmax(0, 1fr) 36px 43px`, 7px gaps, items centred.
    return SizedBox(
      height: 77,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // .ayah-arabic — Naskh, nowrap, #066a5a.
                Text(
                  data.arabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  softWrap: false,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: Dw.arabic,
                    fontSize: data.arabicSize,
                    height: 1.23,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF066A5A),
                  ),
                ),
                const SizedBox(height: 4), // .ayah-meta margin-top
                Text(
                  data.meta,
                  textDirection: TextDirection.rtl,
                  softWrap: false,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: Dw.arabic,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    // rgba(25, 104, 91, .64)
                    color: const Color(0xFF19685B).withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          // .ayah-number — rosette behind the Arabic-Indic verse number.
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DwSvg('assets/09-onboarding/verse-rosette.svg'),
                ),
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        data.number,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: Dw.arabic,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF066A5A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          // .book-badge — 42×42 inside the 43px grid column.
          const SizedBox(
            width: 43,
            child: Center(
              child: SizedBox(
                width: 42,
                height: 42,
                child: DwSvg('assets/09-onboarding/book-badge.svg'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
