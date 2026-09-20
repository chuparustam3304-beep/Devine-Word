import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../widgets/dw_svg.dart';
import '../routing/app_router.dart';
import '../state/app_state_scope.dart';

/// DEVELOPMENT SWITCH — REMOVE BEFORE RELEASE.
///
/// While the onboarding screens are still being polished, set this to
/// `true` so onboarding always shows on launch regardless of the persisted
/// completion flag. Once the screens are finalized, set it back to `false`
/// to restore the production behavior: onboarding plays once, then the
/// splash routes straight to home on every later launch.
const bool kForceOnboardingDuringDevelopment = true;

/// Screen 01 — splash with brand mark and the design's loading indicator.
///
/// The loader shows while the application finishes bringing persisted state
/// online, then routes to onboarding or home depending on completion.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bringOnline());
  }

  /// Gives the brand moment its minimum visibility, then routes to the
  /// first screen of the day.
  Future<void> _bringOnline() async {
    // TEMP-DEBUG: while validating recitation highlighting the app is
    // launched straight on home; without this the splash (which is still
    // below home in the route stack) would replace the whole stack.
    final bool skipSplashRouting = true;
    if (skipSplashRouting) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _routed) return;
    _routed = true;
    final state = AppStateScope.of(context);
    if (!kForceOnboardingDuringDevelopment && state.onboardingComplete) {
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (_) => false);
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.onboardingRead, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DwScreenFrame(
      background: Dw.splashBg,
      body: (context) => Stack(
        children: [
          const DwCoverImage(
            'assets/01-splash/background.png',
            fallbackColor: Dw.splashBg,
          ),
          Positioned(
            left: (Dw.designWidth - 276) / 2,
            top: 181,
            width: 276,
            child: const DwSvg('assets/01-splash/logo-stacked.svg'),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 62,
            child: Column(
              children: [
                DwSvg('assets/01-splash/loading-bar.svg', width: 56, height: 5),
                SizedBox(height: 13),
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Dw.white,
                    shadows: [
                      Shadow(
                        color: Color(0x1F000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
