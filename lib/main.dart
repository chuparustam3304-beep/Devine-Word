import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/app_theme.dart';
import 'routing/app_router.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_listen_screen.dart';
import 'screens/onboarding_read_screen.dart';
import 'screens/onboarding_translation_screen.dart';
import 'screens/recent_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'services/preferences_service.dart';
import 'services/reminder_service.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = PreferencesService(await SharedPreferences.getInstance());
  final state = AppState(preferences: preferences);
  unawaited(state.loadLiveData());
  // Re-arm the persisted daily reminder on every launch — the OS may
  // drop the alarm after a reboot or app update.
  unawaited(
    ReminderService.instance.sync(
      enabled: state.dailyReminder,
      minutes: state.reminderMinutes,
    ),
  );
  runApp(DevineWordApp(state: state));
}

/// Root widget of the Devine Word application.
class DevineWordApp extends StatelessWidget {
  const DevineWordApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder so the theme follows the persisted appearance
    // setting live (Light / Dark / System).
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => AppStateScope(
        state: state,
        child: MaterialApp(
          title: 'Devine Word',
          debugShowCheckedModeBanner: false,
          theme: buildDevineWordTheme(brightness: Brightness.light),
          darkTheme: buildDevineWordTheme(brightness: Brightness.dark),
          themeMode: state.themeMode,
          initialRoute: Routes.splash,
          onGenerateRoute: (settings) {
            final Widget page = switch (settings.name) {
              Routes.onboardingRead => const OnboardingReadScreen(),
              Routes.onboardingListen => const OnboardingListenScreen(),
              Routes.onboardingTranslation =>
                const OnboardingTranslationScreen(),
              Routes.home => const HomeScreen(),
              Routes.saved => const SavedScreen(),
              Routes.recent => const RecentScreen(),
              Routes.settings => const SettingsScreen(),
              _ => const SplashScreen(),
            };
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => page,
            );
          },
        ),
      ),
    );
  }
}
