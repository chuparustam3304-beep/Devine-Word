import 'package:flutter/foundation.dart';

import '../data/api_quran_repository.dart';
import '../data/quran_repository.dart';
import '../services/preferences_service.dart';

/// Central application state backed by [PreferencesService].
///
/// Screens read it through the `AppStateScope` inherited notifier and mutate
/// through the methods below; every mutation is persisted immediately.
class AppState extends ChangeNotifier {
  AppState({
    required PreferencesService preferences,
    ApiQuranRepository? apiRepository,
  }) : _preferences = preferences,
       repository = const QuranRepository(),
       _apiRepository = apiRepository ?? ApiQuranRepository() {
    _onboardingComplete = preferences.onboardingComplete;
  }

  final PreferencesService _preferences;
  final QuranRepository repository;

  /// Live-verse client used to fetch the daily pool at launch (injectable
  /// for tests).
  final ApiQuranRepository _apiRepository;

  bool _onboardingComplete = false;

  bool get onboardingComplete => _onboardingComplete;

  /// Brings the daily pool online (the design set is always available as a
  /// fallback for offline launches). Runs once, unawaited, from `main()`.
  Future<void> loadLiveData() async {
    try {
      final livePool = await _apiRepository.loadDailyPool();
      if (livePool.isEmpty) return;
      QuranRepository.setLivePool(livePool);
    } catch (_) {
      // Offline or API failure — the approved design set stays available.
    }
  }

  /// Marks onboarding complete and persists the flag so the splash routes
  /// straight to home on every later launch.
  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    await _preferences.setOnboardingComplete();
    notifyListeners();
  }
}
