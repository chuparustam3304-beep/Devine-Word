import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../widgets/dw_svg.dart';

/// Canonical route names for the eight finalized screens.
abstract final class Routes {
  static const splash = '/';
  static const onboardingRead = '/onboarding/read';
  static const onboardingListen = '/onboarding/listen';
  static const onboardingTranslation = '/onboarding/translation';
  static const home = '/home';
  static const saved = '/saved';
  static const recent = '/recent';
  static const settings = '/settings';

  /// Bottom-navigation order: home, saved, recent, settings.
  static const tabs = [home, saved, recent, settings];
}

/// The four-lobed bottom navigation asset (`nav.svg`, viewBox 328x88,
/// displayed at 283 CSS px wide). Each of the four lobes is one tab.
class BottomNavImage extends StatelessWidget {
  const BottomNavImage({super.key, required this.asset, required this.onTap});

  final String asset;
  final void Function(int tabIndex) onTap;

  static const double _width = 283;
  static const double _viewBoxWidth = 328;
  static const double _viewBoxHeight = 88;

  @override
  Widget build(BuildContext context) {
    final height = _width * _viewBoxHeight / _viewBoxWidth;
    return Positioned(
      left: (Dw.designWidth - _width) / 2,
      bottom: 18,
      width: _width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final zone =
              (details.localPosition.dx / (_width / Routes.tabs.length))
                  .floor()
                  .clamp(0, Routes.tabs.length - 1);
          onTap(zone);
        },
        child: DwSvg(asset, width: _width, height: height),
      ),
    );
  }
}

/// Navigates the active tab, replacing the current screen so that tab
/// switching does not grow the navigation stack.
void switchTab(BuildContext context, int tabIndex) {
  Navigator.of(context)
      .pushNamedAndRemoveUntil(Routes.tabs[tabIndex], ModalRoute.withName('/'));
}
