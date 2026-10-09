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
