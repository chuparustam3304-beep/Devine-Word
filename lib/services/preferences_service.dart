import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Typed key-space for all persisted application state.
class PreferencesService {
  PreferencesService(this._prefs);

  static const _onboardingDone = 'onboardingComplete';
  static const _translation = 'translationLanguage';
  static const _textSize = 'textSize';
  static const _playTranslation = 'playTranslationAfterArabic';
  static const _dailyReminder = 'dailyReminder';
  static const _appearance = 'appearance';
  static const _bookmarks = 'bookmarkedReferences';
  static const _likes = 'likedReferences';
  static const _recent = 'recentReadingEvents';

  final SharedPreferences _prefs;

  bool get onboardingComplete => _prefs.getBool(_onboardingDone) ?? false;
  Future<void> setOnboardingComplete() => _prefs.setBool(_onboardingDone, true);

  TranslationLanguage get translationLanguage {
    final name = _prefs.getString(_translation);
    return TranslationLanguage.values
            .where((l) => l.name == name)
            .firstOrNull ??
        TranslationLanguage.urdu;
  }

  Future<void> setTranslationLanguage(TranslationLanguage language) =>
      _prefs.setString(_translation, language.name);

  TextSizeOption get textSize {
    final name = _prefs.getString(_textSize);
    return TextSizeOption.values.where((s) => s.name == name).firstOrNull ??
        TextSizeOption.defaultSize;
  }

  Future<void> setTextSize(TextSizeOption size) =>
      _prefs.setString(_textSize, size.name);

  bool get playTranslationAfterArabic =>
      _prefs.getBool(_playTranslation) ?? true;
  Future<void> setPlayTranslationAfterArabic(bool value) =>
      _prefs.setBool(_playTranslation, value);

  bool get dailyReminder => _prefs.getBool(_dailyReminder) ?? false;
  Future<void> setDailyReminder(bool value) =>
      _prefs.setBool(_dailyReminder, value);

  AppearanceMode get appearance =>
      AppearanceMode.values
          .where((m) => m.name == _prefs.getString(_appearance))
          .firstOrNull ??
      AppearanceMode.light;
  Future<void> setAppearance(AppearanceMode mode) =>
      _prefs.setString(_appearance, mode.name);

  static const _reminderMinutes = 'reminderMinutes';

  /// Default reminder time: 08:00 local.
  static const defaultReminderMinutes = 8 * 60;
  int get reminderMinutes =>
      _prefs.getInt(_reminderMinutes) ?? defaultReminderMinutes;
  Future<void> setReminderMinutes(int minutes) =>
      _prefs.setInt(_reminderMinutes, minutes);

  Set<String> get bookmarkedReferences =>
      (_prefs.getStringList(_bookmarks) ?? const []).toSet();
  Future<void> setBookmarkedReferences(Set<String> references) =>
      _prefs.setStringList(_bookmarks, references.toList());

  Set<String> get likedReferences =>
      (_prefs.getStringList(_likes) ?? const []).toSet();
  Future<void> setLikedReferences(Set<String> references) =>
      _prefs.setStringList(_likes, references.toList());

  List<ReadingRecord> get recentReadings {
    final raw = _prefs.getStringList(_recent) ?? const [];
    return raw
        .map((entry) {
          try {
            final map = jsonDecode(entry) as Map<String, dynamic>;
            return ReadingRecord(
              reference: map['reference'] as String,
              surahName: map['surahName'] as String,
              arabic: map['arabic'] as String,
              readAt: DateTime.parse(map['readAt'] as String),
            );
          } on FormatException {
            return null;
          }
        })
        .whereType<ReadingRecord>()
        .toList();
  }

  Future<void> recordReading(ReadingRecord record) async {
    final existing = recentReadings
        .where((r) => r.reference != record.reference)
        .toList();
    existing.insert(0, record);
    final trimmed = existing.take(50).toList();
    await _prefs.setStringList(
      _recent,
      trimmed
          .map(
            (r) => jsonEncode({
              'reference': r.reference,
              'surahName': r.surahName,
              'arabic': r.arabic,
              'readAt': r.readAt.toIso8601String(),
            }),
          )
          .toList(),
    );
  }
}
