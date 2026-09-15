import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/models.dart';
import '../data/quran_repository.dart';
import '../services/preferences_service.dart';
import '../services/reminder_service.dart';

/// Central application state backed by [PreferencesService].
///
/// Screens listen via [ListenableBuilder] and mutate through the methods
/// below; every mutation is persisted immediately.
class AppState extends ChangeNotifier {
  AppState({required PreferencesService preferences})
    : _preferences = preferences,
      repository = const QuranRepository() {
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
