/// Translation options offered on onboarding and in Settings.
enum TranslationLanguage {
  urdu('Urdu', 'اردو'),
  english('English', 'English'),
  bengali('Bengali', 'বাংলা');

  const TranslationLanguage(this.label, this.nativeLabel);

  final String label;
  final String nativeLabel;
}

/// Font-scale preset for the "Text size" setting.
enum TextSizeOption { small, defaultSize, large }

/// Appearance setting: Light, Dark, or follow the OS (System).
enum AppearanceMode {
  light('Light'),
  dark('Dark'),
  system('System');

  const AppearanceMode(this.label);

  final String label;
}

/// A single ayah of the Quran with an approved translation.
///
/// `reference` uses the `surah:ayah` form, e.g. `94:6`.
class Ayah {
  const Ayah({
    required this.reference,
    required this.surahName,
    required this.arabic,
    required this.translations,
  });

  final String reference;
  final String surahName;
  final String arabic;

  /// Translation text keyed by [TranslationLanguage].
  final Map<TranslationLanguage, String> translations;

  String translationFor(TranslationLanguage language) =>
      translations[language] ?? translations.values.first;
}

/// One recorded reading event shown in Recent activity.
class ReadingRecord {
  const ReadingRecord({
    required this.reference,
    required this.surahName,
    required this.arabic,
    required this.readAt,
  });

  final String reference;
  final String surahName;
  final String arabic;
  final DateTime readAt;
}
