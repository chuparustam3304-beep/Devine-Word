import 'package:shared_preferences/shared_preferences.dart';

/// Typed key-space for persisted application state.
///
/// Only the onboarding completion flag is persisted by the app.
class PreferencesService {
  PreferencesService(this._prefs);

  static const _onboardingDone = 'onboardingComplete';

  final SharedPreferences _prefs;

  bool get onboardingComplete => _prefs.getBool(_onboardingDone) ?? false;
  Future<void> setOnboardingComplete() => _prefs.setBool(_onboardingDone, true);

  /// Drops the onboarding flag so the next launch starts at step 1 again.
  ///
  /// Only used by the debug-only reset hatch in `main()`; the app itself never
  /// rewinds onboarding for the user.
  Future<void> clearOnboarding() => _prefs.remove(_onboardingDone);
}
