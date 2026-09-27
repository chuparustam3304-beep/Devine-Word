import 'package:shared_preferences/shared_preferences.dart';

/// Typed key-space for persisted application state.
///
/// The settings surface (translation language, text size, play-after-Arabic,
/// daily reminder and appearance) and the Like/Save/Recent data were removed
/// with the settings, saved, recent and bookmark flows, so only the onboarding
/// flag remains.
class PreferencesService {
  PreferencesService(this._prefs);

  static const _onboardingDone = 'onboardingComplete';

  final SharedPreferences _prefs;

  bool get onboardingComplete => _prefs.getBool(_onboardingDone) ?? false;
  Future<void> setOnboardingComplete() => _prefs.setBool(_onboardingDone, true);
}
