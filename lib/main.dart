import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/app_theme.dart';
import 'routing/app_router.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_grow_screen.dart';
import 'screens/onboarding_journey_screen.dart';
import 'screens/onboarding_quran_screen.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/preferences_service.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = PreferencesService(await SharedPreferences.getInstance());
  // Debug escape hatch for re-testing the onboarding flow:
  // `flutter run --dart-define=DW_RESET_ONBOARDING=true`. The flag lives in the
  // device's app container, so quitting, rebuilding and even `flutter clean`
  // all preserve it; this is the only way to rewind without uninstalling.
  // Runs before `AppState` is built so its constructor reads the cleared value,
  // and `kDebugMode` keeps it out of release builds entirely.
  const resetOnboarding = bool.fromEnvironment('DW_RESET_ONBOARDING');
  if (kDebugMode && resetOnboarding) {
    await preferences.clearOnboarding();
  }
  final state = AppState(preferences: preferences);
  // Prime the daily pool before the first frame; the design set is always
  // available as an offline fallback while the live fetch is in flight.
  unawaited(state.loadLiveData());
  // Start the ad SDK alongside it so the home banner's first request is not
  // delayed; a failure only means no banner (see `AdService`).
  unawaited(AdService.initialize());
  runApp(DevineWordApp(state: state));
}

/// Root widget of the Devine Word application.
class DevineWordApp extends StatelessWidget {
  const DevineWordApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        title: 'Devine Word',
        debugShowCheckedModeBanner: false,
        theme: buildDevineWordTheme(),
        initialRoute: Routes.splash,
        routes: {
          Routes.splash: (_) => const SplashScreen(),
          Routes.onboardingGrow: (_) => const OnboardingGrowScreen(),
          Routes.onboardingJourney: (_) => const OnboardingJourneyScreen(),
          Routes.onboardingQuranic: (_) => const OnboardingQuranScreen(),
          Routes.home: (_) => const HomeScreen(),
        },
      ),
    );
  }
}
