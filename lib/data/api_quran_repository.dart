import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiQuranRepository {
  ApiQuranRepository({
    this.baseUrl = 'https://api.alquran.cloud/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _editions =
      'quran-uthmani,ar.alafasy,en.sahih,ur.jalandhry,bn.bengali';

  final String baseUrl;

  /// Injectable for tests ([MockClient]); defaults to a real HTTP client.
  final http.Client _client;

  Future<Ayah?> findByReference(String reference) async {
    final uri = Uri.parse(
      '$baseUrl/ayah/${Uri.encodeComponent(reference)}/editions/$_editions',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;
    // The API answers `application/json` without a charset header; decode
    // explicitly as UTF-8 (header-based detection would fall back to
    // latin1 and garble the Arabic/Urdu/Bengali text).
    return _parseAyah(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<List<Ayah>> loadDailyPool() async {
    final requests = List<Future<Ayah?>>.generate(5, (_) async {
      final uri = Uri.parse('$baseUrl/ayah/random/editions/$_editions');
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;
      return _parseAyah(jsonDecode(utf8.decode(response.bodyBytes)));
    });
    final ayahs = await Future.wait(requests);
    return ayahs.whereType<Ayah>().toList();
  }

  /// Fetches ONE fresh random ayah — the building block behind the home
  /// screen's "swipe up for another ayah" gesture, so every swipe surfaces
  /// content beyond the fixed pool loaded at launch.
  ///
  /// Random endpoints can hand back an ayah that is already in circulation,
  /// so the request is retried while the result's reference appears in
  /// [excludeReferences] (up to [maxAttempts] tries; the last try accepts
  /// whatever comes back). Returns null when the API is unreachable or
  /// unparseable (e.g. the device is offline) — callers fall back to the
  /// locally available pool.
  Future<Ayah?> fetchRandomAyah({
    Set<String> excludeReferences = const {},
    int maxAttempts = 4,
  }) async {
    final uri = Uri.parse('$baseUrl/ayah/random/editions/$_editions');
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;
        final ayah = _parseAyah(jsonDecode(utf8.decode(response.bodyBytes)));
        if (ayah == null) continue;
        final isRepeat = excludeReferences.contains(ayah.reference);
        if (isRepeat && attempt < maxAttempts - 1) continue;
        return ayah;
      } catch (_) {
        // Network hiccup or timeout — retry, then give up below.
      }
    }
    return null;
  }

  Ayah? _parseAyah(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final data = decoded['data'];
    if (data is! List) return null;

    String? arabic;
    String? english;
    String? urdu;
    String? bengali;
    String? reference;
    String? surahName;
    String? audioUrl;

    for (final item in data) {
      if (item is! Map) continue;
      final edition = item['edition'];
      final identifier = edition is Map ? edition['identifier'] : null;
      final text = item['text']?.toString();
      if (text == null) continue;

      reference ??= '${item['surah']?['number']}:${item['numberInSurah']}';
      surahName ??= item['surah']?['englishName']?.toString();
      switch (identifier) {
        case 'quran-uthmani':
          arabic = text;
        case 'ar.alafasy':
          audioUrl = item['audio']?.toString() ?? audioUrl;
        case 'en.sahih':
          english = text;
        case 'ur.jalandhry':
          urdu = text;
        case 'bn.bengali':
          bengali = text;
      }
    }

    if (arabic == null || reference == null || surahName == null) return null;
    final translations = <TranslationLanguage, String>{};
    if (english != null) translations[TranslationLanguage.english] = english;
    if (urdu != null) translations[TranslationLanguage.urdu] = urdu;
    if (bengali != null) translations[TranslationLanguage.bengali] = bengali;

    return Ayah(
      reference: reference,
      surahName: surahName.toUpperCase(),
      arabic: arabic,
      translations: translations,
      audioUrl: audioUrl,
    );
  }
}
