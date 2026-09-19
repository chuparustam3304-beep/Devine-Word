import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/api_quran_repository.dart';
import '../data/models.dart';
import '../data/quran_repository.dart';
import '../services/preferences_service.dart';
import '../services/reminder_service.dart';

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
    _translation = preferences.translationLanguage;
    _textSize = preferences.textSize;
    _playTranslation = preferences.playTranslationAfterArabic;
    _dailyReminder = preferences.dailyReminder;
    _reminderMinutes = preferences.reminderMinutes;
    _appearance = preferences.appearance;
    _bookmarks = preferences.bookmarkedReferences;
    _likes = preferences.likedReferences;
    _recent = preferences.recentReadings;
  }

  final PreferencesService _preferences;
  final QuranRepository repository;

  /// Live-verse client used to fetch a fresh random ayah on every
  /// home-screen swipe (injectable for tests).
  final ApiQuranRepository _apiRepository;

  bool _isLoadingLiveData = false;
  bool _isFetchingNextAyah = false;
  String? _liveDataError;

  bool _onboardingComplete = false;
  TranslationLanguage _translation = TranslationLanguage.urdu;
  TextSizeOption _textSize = TextSizeOption.defaultSize;
  bool _playTranslation = true;
  bool _dailyReminder = false;
  int _reminderMinutes = PreferencesService.defaultReminderMinutes;
  AppearanceMode _appearance = AppearanceMode.light;
  Set<String> _bookmarks = {};
  Set<String> _likes = {};
  List<ReadingRecord> _recent = [];

  bool get onboardingComplete => _onboardingComplete;
  TranslationLanguage get translation => _translation;
  TextSizeOption get textSize => _textSize;
  bool get playTranslationAfterArabic => _playTranslation;
  bool get dailyReminder => _dailyReminder;

  /// Reminder time as minutes past midnight (0–1439). Default 08:00.
  int get reminderMinutes => _reminderMinutes;
  AppearanceMode get appearanceMode => _appearance;

  /// ThemeMode for MaterialApp, derived from the appearance setting.
  ThemeMode get themeMode => switch (_appearance) {
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
    AppearanceMode.system => ThemeMode.system,
  };
  Set<String> get bookmarks => Set.unmodifiable(_bookmarks);
  Set<String> get likes => Set.unmodifiable(_likes);
  List<ReadingRecord> get recent => List.unmodifiable(_recent);
  bool get isLoadingLiveData => _isLoadingLiveData;

  /// True while a swipe-triggered fetch of the next random ayah is in flight.
  bool get isFetchingNextAyah => _isFetchingNextAyah;
  String? get liveDataError => _liveDataError;

  Future<void> loadLiveData() async {
    _isLoadingLiveData = true;
    _liveDataError = null;
    notifyListeners();

    try {
      final livePool = await ApiQuranRepository().loadDailyPool();
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

  /// Fetches one brand-new random ayah and appends it to the daily pool so
  /// the home feed shows fresh content on every swipe.
  ///
  /// Returns true when a new ayah joined the pool; false when the fetch
  /// failed (offline / API error) or produced nothing new — the home screen
  /// then falls back to rotating the ayat it already has.
  Future<bool> fetchNextAyah() async {
    if (_isFetchingNextAyah) return false;
    _isFetchingNextAyah = true;
    notifyListeners();
    try {
      final inCirculation = repository
          .loadDailyPool()
          .map((ayah) => ayah.reference)
          .toSet();
      final ayah = await _apiRepository.fetchRandomAyah(
        excludeReferences: inCirculation,
      );
      if (ayah == null || inCirculation.contains(ayah.reference)) return false;
      QuranRepository.appendLivePool([ayah]);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isFetchingNextAyah = false;
      notifyListeners();
    }
  }

  bool isBookmarked(String reference) => _bookmarks.contains(reference);
  bool isLiked(String reference) => _likes.contains(reference);

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    await _preferences.setOnboardingComplete();
    notifyListeners();
  }

  Future<void> setTranslation(TranslationLanguage language) async {
    _translation = language;
    await _preferences.setTranslationLanguage(language);
    notifyListeners();
  }

  Future<void> setTextSize(TextSizeOption size) async {
    _textSize = size;
    await _preferences.setTextSize(size);
    notifyListeners();
  }

  Future<void> setPlayTranslationAfterArabic(bool value) async {
    _playTranslation = value;
    await _preferences.setPlayTranslationAfterArabic(value);
    notifyListeners();
  }

  Future<void> setDailyReminder(bool value) async {
    _dailyReminder = value;
    await _preferences.setDailyReminder(value);
    notifyListeners();
    // Keep the OS alarm in step with the toggle (cancel or schedule).
    await ReminderService.instance.sync(
      enabled: value,
      minutes: _reminderMinutes,
    );
  }

  /// Persists a new reminder time (minutes past midnight) and re-arms
  /// the alarm when the reminder is on.
  Future<void> setReminderTime(int minutes) async {
    _reminderMinutes = minutes.clamp(0, 24 * 60 - 1);
    await _preferences.setReminderMinutes(_reminderMinutes);
    notifyListeners();
    if (_dailyReminder) {
      await ReminderService.instance.sync(
        enabled: true,
        minutes: _reminderMinutes,
      );
    }
  }

  /// Persists the appearance choice; the app rebuilds its theme via
  /// the ListenableBuilder around MaterialApp.
  Future<void> setAppearance(AppearanceMode mode) async {
    _appearance = mode;
    await _preferences.setAppearance(mode);
    notifyListeners();
  }

  Future<void> toggleBookmark(String reference) async {
    final next = Set<String>.from(_bookmarks);
    if (!next.remove(reference)) next.add(reference);
    _bookmarks = next;
    await _preferences.setBookmarkedReferences(next);
    notifyListeners();
  }

  Future<void> toggleLike(String reference) async {
    final next = Set<String>.from(_likes);
    if (!next.remove(reference)) next.add(reference);
    _likes = next;
    await _preferences.setLikedReferences(next);
    notifyListeners();
  }

  /// Records a reading event for Recent activity (newest first).
  Future<void> recordRead(Ayah ayah) async {
    final record = ReadingRecord(
      reference: ayah.reference,
      surahName: ayah.surahName,
      arabic: ayah.arabic,
      readAt: DateTime.now(),
    );
    _recent = [record, ..._recent.where((r) => r.reference != ayah.reference)];
    await _preferences.recordReading(record);
    notifyListeners();
  }
}
