import 'dart:convert';

import 'package:http/http.dart' as http;

/// One word's recitation window inside a single ayah's audio, in
/// milliseconds relative to the start of that ayah's file.
class AyahWordTiming {
  const AyahWordTiming({
    required this.word,
    required this.startMs,
    required this.endMs,
  });

  /// 1-based index of the word within the ayah (Uthmani orthography).
  final int word;
  final int startMs;
  final int endMs;
}

/// Resolves word-level recitation timings for the synced text highlighter.
///
/// Segment data comes from the quran.com/QUL dataset for the reciter that
/// matches the app's audio (Mishari al-Afasy, reciter id 7). There the
/// segments are offsets into a chapter's gapless audio, so they are
/// re-based here onto each ayah's own file start.
class RecitationTimingService {
  RecitationTimingService({
    http.Client? client,
    this.reciterId = alafasyReciterId,
  }) : _client = client ?? http.Client();

  static RecitationTimingService? _shared;
  static RecitationTimingService get instance =>
      _shared ??= RecitationTimingService();

  /// quran.com reciter id for Mishari Rashid al-Afasy — the same
  /// recordings the app streams from the islamic.network CDN.
  static const int alafasyReciterId = 7;

  static const String _endpointBase =
      'https://api.quran.com/api/qdc/audio/reciters';

  final http.Client _client;
  final int reciterId;

  /// reference → timings; null = not fetched yet, empty list = fetched and
  /// unavailable (kept so a swipe storm doesn't hammer the API).
  final Map<String, List<AyahWordTiming>?> _cache = {};

  /// Word timings for a `surah:ayah` [reference], or null when unavailable
  /// (offline, API error, or no segment data for that ayah).
  Future<List<AyahWordTiming>?> forReference(String reference) async {
    if (_cache.containsKey(reference)) {
      final cached = _cache[reference];
      return cached == null || cached.isEmpty ? null : cached;
    }
    final surah = int.tryParse(reference.split(':').first);
    if (surah == null || surah < 1 || surah > 114) {
      _cache[reference] = const [];
      return null;
    }
    try {
      final uri = Uri.parse(
        '$_endpointBase/$reciterId/audio_files?chapter=$surah&segments=true',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _cache[reference] = const [];
        return null;
      }
      final timings = parseVerseSegments(
        utf8.decode(response.bodyBytes),
        reference,
      );
      _cache[reference] = timings;
      return timings.isEmpty ? null : timings;
    } catch (_) {
      // Network hiccup — don't cache the failure; a later attempt retries.
      return null;
    }
  }

  /// Extracts the segments for [reference] from a chapter `audio_files`
  /// payload and re-bases them onto the ayah's own start (0 ms). Pure
  /// function — unit tested.
  static List<AyahWordTiming> parseVerseSegments(
    String body,
    String reference,
  ) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final files = decoded['audio_files'];
    if (files is! List || files.isEmpty) return const [];
    final file = files.first;
    if (file is! Map) return const [];
    final verseTimings = file['verse_timings'];
    if (verseTimings is! List) return const [];

    for (final entry in verseTimings) {
      if (entry is! Map) continue;
      if (entry['verse_key']?.toString() != reference) continue;
      final segments = entry['segments'];
      if (segments is! List || segments.isEmpty) return const [];
      final parsed = <AyahWordTiming>[];
      for (final segment in segments) {
        if (segment is! List || segment.length < 3) continue;
        final word = (segment[0] as num).toInt();
        final start = (segment[1] as num).toInt();
        final end = (segment[2] as num).toInt();
        if (word < 1 || end < start) continue;
        parsed.add(AyahWordTiming(word: word, startMs: start, endMs: end));
      }
      if (parsed.isEmpty) return const [];
      // Re-base: the first segment marks where this ayah's recitation
      // begins within the chapter file (0 in the ayah's own file).
      final offset = parsed.first.startMs;
      return [
        for (final timing in parsed)
          AyahWordTiming(
            word: timing.word,
            startMs: timing.startMs - offset < 0 ? 0 : timing.startMs - offset,
            endMs: timing.endMs - offset,
          ),
      ];
    }
    return const [];
  }
}

/// 0-based index of the word being recited at [positionMs], or -1 before
/// the first word. A word stays active until the next one starts, so the
/// highlight also rests on the final word after a track finishes.
///
/// The value is an index into the *segment* word space — the word numbering
/// the recitation timings use, which is not always the same as the word
/// numbering of the displayed text (see [segmentWordsForTextWords]).
int activeWordIndex(List<AyahWordTiming> timings, int positionMs) {
  var active = -1;
  for (final timing in timings) {
    if (timing.startMs > positionMs) break;
    active = timing.word - 1;
  }
  return active;
}

/// Highest word number the [timings] cover.
int maxSegmentWord(List<AyahWordTiming> timings) {
  var maxWord = 0;
  for (final timing in timings) {
    if (timing.word > maxWord) maxWord = timing.word;
  }
  return maxWord;
}

/// Maps every word of the *displayed* ayah [textWordCount] onto the word
/// numbering used by the recitation [timings].
///
/// The two numberings usually agree, but they can drift: the timing data
/// splits or joins words differently from the Uthmani text (and, on a few
/// ayat, a word is recited across several segments, so
/// `timings.length != number of words`). When the counts line up the mapping
/// is the identity; otherwise the words are spread proportionally across the
/// segment range so the highlight follows the recitation instead of being
/// switched off. Either way the result stays inside `1..maxSegmentWord`.
List<int> segmentWordsForTextWords(
  List<AyahWordTiming> timings,
  int textWordCount,
) {
  if (textWordCount <= 0) return const [];
  final maxWord = maxSegmentWord(timings);
  if (maxWord <= 0) return const [];
  if (textWordCount == maxWord) {
    return [for (var word = 1; word <= textWordCount; word++) word];
  }
  return [
    for (var word = 1; word <= textWordCount; word++)
      ((word - 1) * maxWord) ~/ textWordCount + 1,
  ];
}

