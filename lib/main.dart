import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/app_theme.dart';
import 'routing/app_router.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_grow_screen.dart';
import 'screens/onboarding_journey_screen.dart';
import 'screens/onboarding_quran_screen.dart';
import 'screens/splash_screen.dart';
import 'services/preferences_service.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = PreferencesService(await SharedPreferences.getInstance());
  final state = AppState(preferences: preferences);
  // Prime the daily pool before the first frame; the design set is always
  // available as an offline fallback while the live fetch is in flight.
  unawaited(state.loadLiveData());
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
        onGenerateRoute: (settings) {
          final Widget page = switch (settings.name) {
            Routes.onboardingJourney => const OnboardingJourneyScreen(),
            Routes.onboardingGrow => const OnboardingGrowScreen(),
            Routes.onboardingQuranic => const OnboardingQuranScreen(),
            Routes.home => const HomeScreen(),
            _ => const SplashScreen(),
          };
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => page,
          );
        },
      ),
    );
  }
}
