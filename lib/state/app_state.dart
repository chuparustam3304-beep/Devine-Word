import 'package:flutter/foundation.dart';

import '../data/api_quran_repository.dart';
import '../data/quran_repository.dart';
import '../services/preferences_service.dart';

/// Central application state backed by [PreferencesService].
///
/// Screens listen via [ListenableBuilder] and mutate through the methods
/// below; every mutation is persisted immediately.
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

  /// Live-verse client used to fetch the daily pool at launch (injectable for
  /// tests). Replaces the older per-swipe `fetchNextAyah` flow, which was
  /// removed together with the swipe-up gesture.
  final ApiQuranRepository _apiRepository;

  bool _isLoadingLiveData = false;
  String? _liveDataError;

  bool _onboardingComplete = false;

  bool get onboardingComplete => _onboardingComplete;
  bool get isLoadingLiveData => _isLoadingLiveData;
  String? get liveDataError => _liveDataError;

  /// Brings the daily pool online (the design set is always available as a
  /// fallback for offline launches). Runs once, unawaited, from `main()`.
  Future<void> loadLiveData() async {
    _isLoadingLiveData = true;
    _liveDataError = null;
    notifyListeners();

    try {
      final livePool = await _apiRepository.loadDailyPool();
      if (livePool.isEmpty) {
        throw Exception('The Quran API returned no ayahs.');
      }
      QuranRepository.setLivePool(livePool);
    } catch (error) {
      _liveDataError = error.toString();
    } finally {
      _isLoadingLiveData = false;
      notifyListeners();
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
