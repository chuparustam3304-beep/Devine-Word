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
    this.audioUrl,
  });

  final String reference;
  final String surahName;
  final String arabic;

  /// Translation text keyed by [TranslationLanguage].
  final Map<TranslationLanguage, String> translations;

  /// Recitation stream for this ayah (Mishary Alafasy) when the live API
  /// supplies one; null for offline design content.
  final String? audioUrl;

  String translationFor(TranslationLanguage language) =>
      translations[language] ?? translations.values.first;

  /// Recitation stream for this ayah, always resolvable: the live API's
  /// audio URL when present, otherwise the islamic.network CDN URL derived
  /// from the reference — so the play control always has something to load
  /// even for the offline design ayat.
  String get recitationUrl {
    final provided = audioUrl;
    if (provided != null && provided.isNotEmpty) return provided;
    final parts = reference.split(':');
    final surah = int.tryParse(parts.first) ?? 1;
    final numberInSurah = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    var global = numberInSurah;
    for (var i = 0; i < surah - 1 && i < _surahAyahCounts.length; i++) {
      global += _surahAyahCounts[i];
    }
    return 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$global.mp3';
  }

  factory Ayah.fromJson(Map<String, dynamic> json) {
    final ref = json['reference'] ?? json['verse_key'] ?? json['verseKey'] ?? '';
    final surah = json['surah_name'] ?? json['surah'] ?? '';
    final arabic = json['arabic'] ?? json['text'] ?? json['text_uthmani'] ?? '';

    final Map<TranslationLanguage, String> map = {};
    final translations = json['translations'] ?? json['translation'] ?? {};
    if (translations is Map) {
      // try language keys
      if (translations['en'] != null) map[TranslationLanguage.english] = translations['en'];
      if (translations['ur'] != null) map[TranslationLanguage.urdu] = translations['ur'];
      // fallback: single translation text
      if (map.isEmpty && translations['text'] != null) map[TranslationLanguage.english] = translations['text'];
    } else if (translations is List) {
      // assume first is english, second may be urdu
      if (translations.isNotEmpty) map[TranslationLanguage.english] = translations[0]['text'] ?? translations[0];
      if (translations.length > 1) map[TranslationLanguage.urdu] = translations[1]['text'] ?? translations[1];
    }

    // final fallback: any top-level english/urdu keys
    if (map[TranslationLanguage.english] == null && json['translation_en'] != null) {
      map[TranslationLanguage.english] = json['translation_en'];
    }
    if (map[TranslationLanguage.urdu] == null && json['translation_ur'] != null) {
      map[TranslationLanguage.urdu] = json['translation_ur'];
    }

    return Ayah(reference: ref.toString(), surahName: surah.toString(), arabic: arabic.toString(), translations: map);
  }
}

/// Number of ayat in each surah (1–114), used to map a `surah:ayah`
/// reference to the global ayah number the recitation CDN addresses
/// (verified against api.alquran.cloud; total 6236).
const List<int> _surahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, // 1-10
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135, // 11-20
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, // 21-30
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85, // 31-40
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, // 41-50
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13, // 51-60
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, // 61-70
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42, // 71-80
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, // 81-90
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11, // 91-100
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, // 101-110
  5, 4, 5, 6, // 111-114
];

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
