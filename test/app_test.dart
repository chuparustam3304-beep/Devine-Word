import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devine_word/data/api_quran_repository.dart';
import 'package:devine_word/data/models.dart';
import 'package:devine_word/data/recitation_timing.dart';
import 'package:devine_word/data/quran_repository.dart';
import 'package:devine_word/design/app_theme.dart';
import 'package:devine_word/design/tokens.dart';
import 'package:devine_word/main.dart';
import 'package:devine_word/screens/home_screen.dart';
import 'package:devine_word/screens/settings_screen.dart';
import 'package:devine_word/services/audio_service.dart';
import 'package:devine_word/services/preferences_service.dart';
import 'package:devine_word/state/app_state.dart';
import 'package:devine_word/state/app_state_scope.dart';
import 'package:devine_word/widgets/draggable_play_button.dart';
import 'package:devine_word/widgets/dw_svg.dart';
import 'package:devine_word/widgets/settings_bits.dart';
import 'package:devine_word/widgets/synced_ayah_text.dart';

void main() {
  group('QuranRepository', () {
    const repository = QuranRepository();

    test('daily pool contains the approved design ayat', () {
      final pool = repository.loadDailyPool();
      expect(pool, isNotEmpty);
      expect(
        pool.map((a) => a.reference),
        containsAll(['94:6', '13:28', '20:114']),
      );
    });

    test('finds an ayah by reference and returns null otherwise', () {
      expect(repository.findByReference('94:6'), isNotNull);
      expect(repository.findByReference('1:1'), isNull);
    });
    test('ayah translation falls back when language is missing', () {
      final ayah = repository.findByReference('94:6')!;
      expect(ayah.translationFor(TranslationLanguage.english), isNotEmpty);
    });

    test('appendLivePool grows the pool and skips known references', () {
      QuranRepository.resetLivePoolForTest();
      final before = repository.loadDailyPool().length;
      QuranRepository.appendLivePool([
        const Ayah(
          reference: '112:1',
          surahName: 'AL-IKHLAS',
          arabic: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
          translations: {
            TranslationLanguage.english: 'Say: He is Allah, the One;',
          },
        ),
        // A reference already in circulation must not be added twice.
        const Ayah(
          reference: '94:6',
          surahName: 'ASH-SHARH',
          arabic: 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
          translations: {},
        ),
      ]);
      final pool = repository.loadDailyPool();
      expect(pool.length, before + 1);
      expect(pool.last.reference, '112:1');
    });
  });

  group('Ayah.recitationUrl', () {
    test('prefers the stream provided by the live API', () {
      const ayah = Ayah(
        reference: '2:255',
        surahName: 'AL-BAQARAH',
        arabic: 'اللَّهُ',
        translations: {},
        audioUrl: 'https://example.com/provided.mp3',
      );
      expect(ayah.recitationUrl, 'https://example.com/provided.mp3');
    });

    test('derives the CDN URL from the reference (2:255 → global 262)', () {
      const ayah = Ayah(
        reference: '2:255',
        surahName: 'AL-BAQARAH',
        arabic: 'اللَّهُ',
        translations: {},
      );
      expect(
        ayah.recitationUrl,
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3',
      );
    });

    test('derives late-Quran references correctly (112:1 → global 6222)', () {
      const ayah = Ayah(
        reference: '112:1',
        surahName: 'AL-IKHLAS',
        arabic: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        translations: {},
      );
      expect(ayah.recitationUrl, endsWith('/6222.mp3'));
    });
  });

  group('RecitationTimingService', () {
    const chapterBody = '''
{
  "audio_files": [{
    "chapter_id": 94,
    "audio_url": "https://download.quranicaudio.com/qdc/mishari_al_afasy/murattal/94.mp3",
    "verse_timings": [
      {
        "verse_key": "94:1",
        "timestamp_from": 0,
        "segments": [[1, 0, 750], [2, 750, 1500], [3, 1500, 1960], [4, 1960, 3515]]
      },
      {
        "verse_key": "94:6",
        "timestamp_from": 21530,
        "segments": [
          [1, 21530, 22930],
          [2, 22930, 23310],
          [3, 23310, 24180],
          [4, 24180, 25655]
        ]
      }
    ]
  }]
}
''';

    test('re-bases segments onto the ayah start', () {
      final timings = RecitationTimingService.parseVerseSegments(
        chapterBody,
        '94:6',
      );
      expect(timings.map((t) => t.word), [1, 2, 3, 4]);
      expect(timings.first.startMs, 0);
      expect(timings.first.endMs, 1400);
      expect(timings[2].startMs, 1780);
      expect(timings.last.endMs, 4125);
    });

    test('returns nothing for an ayah without segments', () {
      expect(
        RecitationTimingService.parseVerseSegments(chapterBody, '94:99'),
        isEmpty,
      );
    });
  });

  group('activeWordIndex', () {
    const timings = [
      AyahWordTiming(word: 1, startMs: 0, endMs: 750),
      AyahWordTiming(word: 2, startMs: 750, endMs: 1500),
      AyahWordTiming(word: 3, startMs: 1500, endMs: 1960),
    ];

    test('is -1 before the first word', () {
      expect(activeWordIndex(timings, -1), -1);
    });

    test('activates the first word at 0 ms', () {
      expect(activeWordIndex(timings, 0), 0);
    });

    test('moves at the boundary between words', () {
      expect(activeWordIndex(timings, 750), 1);
      expect(activeWordIndex(timings, 1200), 1);
    });

    test('rests on the last word after the track ends', () {
      expect(activeWordIndex(timings, 5000), 2);
    });
  });

  group('segmentWordsForTextWords', () {
    /// Real-world case: 17:93 ships 29 segments whose word numbers top out
    /// at 26, while the Uthmani text has 29 words. Without a mapping the
    /// highlight never matched and was switched off entirely.
    final spread = [
      for (var word = 1; word <= 29; word++)
        AyahWordTiming(
          word: word <= 25 ? word : word - 3,
          startMs: word * 100,
          endMs: word * 100 + 100,
        ),
    ];

    test('is the identity when the counts agree', () {
      const timings = [
        AyahWordTiming(word: 1, startMs: 0, endMs: 10),
        AyahWordTiming(word: 2, startMs: 10, endMs: 20),
        AyahWordTiming(word: 3, startMs: 20, endMs: 30),
      ];
      expect(segmentWordsForTextWords(timings, 3), [1, 2, 3]);
    });

    test('stays inside the segment word range when they differ', () {
      final mapping = segmentWordsForTextWords(spread, 29);
      expect(mapping, hasLength(29));
      expect(mapping.first, 1);
      expect(mapping.last, 26);
      expect(mapping.every((word) => word >= 1 && word <= 26), isTrue);
    });

    test('never maps a word beyond the last segment', () {
      const timings = [
        AyahWordTiming(word: 1, startMs: 0, endMs: 500),
        AyahWordTiming(word: 2, startMs: 500, endMs: 1000),
      ];
      final mapping = segmentWordsForTextWords(timings, 5);
      expect(mapping, [1, 1, 1, 2, 2]);
    });

    test('returns nothing for empty input', () {
      expect(segmentWordsForTextWords(const [], 3), isEmpty);
      expect(
        segmentWordsForTextWords(const [
          AyahWordTiming(word: 1, startMs: 0, endMs: 10),
        ], 0),
        isEmpty,
      );
    });
  });

  group('SyncedAyahText', () {
    const timings = [
      AyahWordTiming(word: 1, startMs: 0, endMs: 1000),
      AyahWordTiming(word: 2, startMs: 1000, endMs: 2000),
      AyahWordTiming(word: 3, startMs: 2000, endMs: 3000),
      AyahWordTiming(word: 4, startMs: 3000, endMs: 4000),
    ];

    /// The recited word is marked by a green stroke outline (`Dw.ayahGreen`
    /// via `TextStyle.foreground` with `PaintingStyle.stroke`); the rest of
    /// the ayah keeps the default ink colour (`Dw.arabicBase` / caller color).
    /// No span should use a background fill (container highlight).
    int greenSpanCount(WidgetTester tester) {
      final richTexts = tester.widgetList(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      var count = 0;
      for (final widget in richTexts) {
        final root = (widget as Text).textSpan;
        final spans = root is TextSpan
            ? (root.children ?? const <InlineSpan>[])
            : const <InlineSpan>[];
        count += spans
            .whereType<TextSpan>()
            .where(
              (span) =>
                  span.style?.foreground?.style == PaintingStyle.stroke &&
                  span.style?.foreground?.color?.value == Dw.ayahGreen.value,
            )
            .length;
      }
      return count;
    }

    /// Spans still carrying a painted background — the container highlight
    /// this widget must no longer use.
    int backgroundSpanCount(WidgetTester tester) {
      final richTexts = tester.widgetList(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      var count = 0;
      for (final widget in richTexts) {
        final root = (widget as Text).textSpan;
        final spans = root is TextSpan
            ? (root.children ?? const <InlineSpan>[])
            : const <InlineSpan>[];
        count += spans
            .whereType<TextSpan>()
            .where((span) => span.style?.background != null)
            .length;
      }
      return count;
    }

    /// Spans carrying a painted stroke outline — the active highlight approach.
    /// Should match [greenSpanCount] since only green strokes are used.
    int strokedSpanCount(WidgetTester tester) {
      final richTexts = tester.widgetList(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      var count = 0;
      for (final widget in richTexts) {
        final root = (widget as Text).textSpan;
        final spans = root is TextSpan
            ? (root.children ?? const <InlineSpan>[])
            : const <InlineSpan>[];
        count += spans
            .whereType<TextSpan>()
            .where(
              (span) => span.style?.foreground?.style == PaintingStyle.stroke,
            )
            .length;
      }
      return count;
    }

    Future<void> pumpHighlighter(
      WidgetTester tester, {
      required StreamController<Duration> positions,
      RecitationTimingService? timingsService,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SyncedAyahText(
            arabic: 'كَلِمَةٌ ۚ ثَانِيَةٌ ثَالِثَةٌ رَابِعَةٌ',
            reference: '1:1',
            audioUrl: 'https://example.com/recitation/001001.mp3',
            timingsService: timingsService ?? _FakeTimingsService(timings),
            positionStream: positions.stream,
            style: const TextStyle(fontSize: 30, color: Colors.black),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('highlights the recited word in ayah green', (tester) async {
      final fakeAudio = _FakeAudioService();
      AudioService.instance = fakeAudio;
      addTearDown(() => AudioService.instance = AudioService());
      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);

      await pumpHighlighter(tester, positions: positions);
      // No position yet — nothing highlighted.
      expect(greenSpanCount(tester), 0);
      expect(backgroundSpanCount(tester), 0);
      // No recited word yet — no stroke outline.
      expect(strokedSpanCount(tester), 0);

      // This ayah's audio is buffered, mid-way through word 2. The
      // pause-mark token between words 1 and 2 is skipped in the mapping.
      fakeAudio.fakeLoadedUrl = 'https://example.com/recitation/001001.mp3';
      positions.add(const Duration(milliseconds: 1500));
      await tester.idle();
      await tester.pump();
      expect(greenSpanCount(tester), 1);
      // A stroke outline, not a container: no span may carry a background fill.
      expect(backgroundSpanCount(tester), 0);
      // The recited word carries a green stroke outline.
      expect(strokedSpanCount(tester), 1);

      // Another ayah's audio — highlight off.
      fakeAudio.fakeLoadedUrl = 'https://example.com/other.mp3';
      positions.add(const Duration(milliseconds: 1600));
      await tester.idle();
      await tester.pump();
      expect(greenSpanCount(tester), 0);
      expect(strokedSpanCount(tester), 0);
    });

    testWidgets('keeps highlighting when the numbering differs', (
      tester,
    ) async {
      final fakeAudio = _FakeAudioService();
      AudioService.instance = fakeAudio;
      addTearDown(() => AudioService.instance = AudioService());
      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);

      // Only two word timings for four letter-words (the dataset splits the
      // recitation differently). The words must still be mapped onto the
      // timings — and never silently dropped, which killed the highlight.
      const shortTimings = [
        AyahWordTiming(word: 1, startMs: 0, endMs: 500),
        AyahWordTiming(word: 2, startMs: 500, endMs: 1000),
      ];
      await pumpHighlighter(
        tester,
        positions: positions,
        timingsService: _FakeTimingsService(shortTimings),
      );
      fakeAudio.fakeLoadedUrl = 'https://example.com/recitation/001001.mp3';

      // Word 1 of the recitation covers the first two text words.
      positions.add(const Duration(milliseconds: 300));
      await tester.idle();
      await tester.pump();
      expect(greenSpanCount(tester), 2);
      expect(backgroundSpanCount(tester), 0);
      expect(strokedSpanCount(tester), 2);

      // Word 2 covers the last two.
      positions.add(const Duration(milliseconds: 700));
      await tester.idle();
      await tester.pump();
      final green = tester
          .widgetList(
            find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
          )
          .expand((w) => ((w as Text).textSpan! as TextSpan).children!)
          .whereType<TextSpan>()
          .where(
            (span) =>
                span.style?.foreground?.style == PaintingStyle.stroke &&
                span.style?.foreground?.color?.value == Dw.ayahGreen.value,
          )
          .map((span) => span.text)
          .toList();
      expect(green, hasLength(2));
      expect(green.first, 'ثَالِثَةٌ');
      // Highlight is a green stroke outline on the recited words, not a container.
      expect(strokedSpanCount(tester), 2);
      expect(backgroundSpanCount(tester), 0);
    });

    testWidgets(
      'highlights the recited word in ayah green, leaves the rest as the caller specified',
      (tester) async {
        final fakeAudio = _FakeAudioService();
        AudioService.instance = fakeAudio;
        addTearDown(() => AudioService.instance = AudioService());
        final positions = StreamController<Duration>.broadcast();
        addTearDown(positions.close);

        const callerColor = Colors.black;
        await pumpHighlighter(tester, positions: positions);
        fakeAudio.fakeLoadedUrl = 'https://example.com/recitation/001001.mp3';
        positions.add(const Duration(milliseconds: 1500));
        await tester.idle();
        await tester.pump();

        // The ayah is a single filled pass, not a fill-under-outline stack.
        final richTexts = tester.widgetList(
          find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
        );
        final allSpans = richTexts
            .expand(
              (w) =>
                  ((w as Text).textSpan! as TextSpan).children ??
                  const <InlineSpan>[],
            )
            .whereType<TextSpan>()
            .toList();

        // The recited word is 'ثَانِيَةٌ' (mid-way through word 2) and it is
        // emphasised with a green stroke outline via `foreground` paint.
        final recitedWord = allSpans.firstWhere(
          (span) => span.text == 'ثَانِيَةٌ',
        );
        expect(recitedWord.style?.color, isNull);
        expect(recitedWord.style?.foreground, isNotNull);
        expect(recitedWord.style?.foreground?.style, PaintingStyle.stroke);
        expect(recitedWord.style?.foreground?.color?.value, Dw.ayahGreen.value);

        // Every other Arabic word keeps the caller's colour, not green.
        final otherWords = allSpans
            .where((span) => span.text != 'ثَانِيَةٌ' && span.text != ' ')
            .toList();
        expect(otherWords, hasLength(4));
        for (final span in otherWords) {
          expect(span.style?.color, callerColor);
          expect(span.style?.foreground, isNull);
        }

        // Highlight is a green stroke outline, not a container fill. The
        // recited word keeps the same weight as the rest of the ayah, so the
        // emphasis comes from the outline, not a heavier weight.
        expect(strokedSpanCount(tester), 1);
        expect(backgroundSpanCount(tester), 0);
        final recitedWeight = recitedWord.style?.fontWeight;
        for (final span in otherWords) {
          expect(span.style?.fontWeight, recitedWeight);
        }
      },
    );
  });

  group('AppState', () {
    test('bookmarks toggle and persist in memory', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      expect(state.isBookmarked('94:6'), isFalse);
      await state.toggleBookmark('94:6');
      expect(state.isBookmarked('94:6'), isTrue);
      await state.toggleBookmark('94:6');
      expect(state.isBookmarked('94:6'), isFalse);
    });

    test('reading records are stored newest first', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      final ayah = state.repository.findByReference('94:6')!;
      await state.recordRead(ayah);
      expect(state.recent.single.reference, '94:6');
    });

    test('fetchNextAyah appends a brand-new ayah to the pool', () async {
      SharedPreferences.setMockInitialValues({});
      // Hermetic start: design pool only, so the fetched references are
      // guaranteed fresh.
      QuranRepository.resetLivePoolForTest();
      var call = 0;
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async {
            call++;
            return http.Response(
              jsonEncode({
                'code': 200,
                'status': 'OK',
                'data': [
                  {
                    'edition': {'identifier': 'quran-uthmani'},
                    'text': 'آية تجريبية $call',
                    'numberInSurah': call,
                    'surah': {'number': 100 + call, 'englishName': 'Surah'},
                  },
                  {
                    'edition': {'identifier': 'en.sahih'},
                    'text': 'Fresh translation $call',
                  },
                ],
              }),
              200,
              // Explicit UTF-8 charset so the Arabic body string round-trips
              // — http defaults to latin1 without a JSON/charset type.
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final initial = state.repository.loadDailyPool().length;

      expect(await state.fetchNextAyah(), isTrue);
      expect(state.repository.loadDailyPool().length, initial + 1);

      // A second swipe must surface yet another distinct ayah, not repeat.
      final first = state.repository.loadDailyPool().last;
      expect(await state.fetchNextAyah(), isTrue);
      final second = state.repository.loadDailyPool().last;
      expect(state.repository.loadDailyPool().length, initial + 2);
      expect(second.reference, isNot(first.reference));
    });

    test('fetchNextAyah fails gracefully offline and keeps the pool', () async {
      SharedPreferences.setMockInitialValues({});
      QuranRepository.resetLivePoolForTest();
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async => http.Response('offline', 503)),
        ),
      );
      final before = state.repository.loadDailyPool().length;
      expect(await state.fetchNextAyah(), isFalse);
      expect(state.repository.loadDailyPool().length, before);
    });
  });

  group('DevineWordApp', () {
    testWidgets('splash renders the brand mark', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      await tester.pumpWidget(DevineWordApp(state: state));
      // Renders the loader immediately...
      expect(find.text('Loading...'), findsOneWidget);
      // ...then pumps past the brand-moment delay so navigation to the
      // first screen runs; the tree must settle with no exceptions.
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      // The approved headline joins three lines in one Text widget.
      expect(find.text('A closer\nconnection to\nthe Quran'), findsOneWidget);
    });
  });

  // (The player-card test was removed with the card itself; the
  // play/pause control now lives in the draggable floating bubble.)

  group('HomeScreen', () {
    testWidgets('long ayah at max text size flows without overflow', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      QuranRepository.resetLivePoolForTest();
      addTearDown(QuranRepository.resetLivePoolForTest);
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        // Deterministic offline fetch: swipes fall back to rotating the
        // built-in pool, exactly as on an offline device.
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async => http.Response('offline', 503)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDevineWordTheme(),
          home: AppStateScope(state: state, child: const HomeScreen()),
        ),
      );
      await tester.pump();

      // Advance the pool to the longest ayah (2:255, Ayat al-Kursi) —
      // "Swipe up for another ayah" is tapped 3 times from index 0.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Swipe up for another ayah'));
        await tester.pump();
      }
      expect(find.text('AL-BAQARAH'), findsOneWidget);

      // Max out the text-size stepper (5 presses).
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('Increase text size'));
        await tester.pump();
      }
      await tester.pump();

      // The ayah block must reflow/scale down — never paint an overflow
      // banner or collide with the player card.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'floating play bubble parks by the swipe strip, toggles and drags',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        // Hermetic pool: one ayah carrying a recitation stream so the
        // floating control has something real to play.
        QuranRepository.resetLivePoolForTest();
        QuranRepository.setLivePool([
          const Ayah(
            reference: '1:1',
            surahName: 'AL-FATIHAH',
            arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            translations: {
              TranslationLanguage.english:
                  'In the name of Allah, the Most Gracious, the Most Merciful.',
            },
            audioUrl: 'https://example.com/recitation/001001.mp3',
          ),
        ]);
        addTearDown(QuranRepository.resetLivePoolForTest);

        // Swap the real audio stack for a fake — no platform channels here.
        final fakeAudio = _FakeAudioService();
        AudioService.instance = fakeAudio;
        addTearDown(() => AudioService.instance = AudioService());

        final state = AppState(
          preferences: PreferencesService(
            await SharedPreferences.getInstance(),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDevineWordTheme(),
            home: AppStateScope(state: state, child: const HomeScreen()),
          ),
        );
        await tester.pump();

        final bubble = find.byType(DraggablePlayButton);
        expect(bubble, findsOneWidget);

        Positioned posOf() => tester.widget<Positioned>(
          find.descendant(of: bubble, matching: find.byType(Positioned)),
        );

        // Initial parking spot: left 25px card inset, just above the
        // "Swipe up for another ayah" strip.
        expect(posOf().left, 25);
        expect(posOf().top, 655);

        // Starts honestly paused (play triangle); tapping plays the
        // recitation (pause bars); tapping again pauses.
        DwSvg bubbleIcon() => tester.widget<DwSvg>(
          find.descendant(of: bubble, matching: find.byType(DwSvg)),
        );
        expect(bubbleIcon().asset, 'assets/05-home/play.svg');
        await tester.tap(bubble);
        await tester.pump();
        expect(bubbleIcon().asset, 'assets/05-home/pause.svg');
        expect(
          fakeAudio.playedUrls.single,
          'https://example.com/recitation/001001.mp3',
        );
        await tester.tap(bubble);
        await tester.pump();
        expect(bubbleIcon().asset, 'assets/05-home/play.svg');

        // Dragging far right/down parks the bubble against the clamp
        // bounds (8px margin inside the 393x852 design frame).
        await tester.drag(bubble, const Offset(2000, 0));
        await tester.pump();
        expect(posOf().left, 393 - 60 - 8);
        await tester.drag(bubble, const Offset(0, 2000));
        await tester.pump();
        expect(posOf().top, 852 - 60 - 8);
        expect(posOf().left, 393 - 60 - 8);
      },
    );

    testWidgets('pause then play resumes without re-buffering', (tester) async {
      SharedPreferences.setMockInitialValues({});
      QuranRepository.resetLivePoolForTest();
      QuranRepository.setLivePool([
        const Ayah(
          reference: '1:1',
          surahName: 'AL-FATIHAH',
          arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          translations: {
            TranslationLanguage.english:
                'In the name of Allah, the Most Gracious, the Most Merciful.',
          },
          audioUrl: 'https://example.com/recitation/001001.mp3',
        ),
      ]);
      addTearDown(QuranRepository.resetLivePoolForTest);
      final fakeAudio = _FakeAudioService();
      AudioService.instance = fakeAudio;
      addTearDown(() => AudioService.instance = AudioService());

      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDevineWordTheme(),
          home: AppStateScope(state: state, child: const HomeScreen()),
        ),
      );
      await tester.pump();

      final bubble = find.byType(DraggablePlayButton);

      // Play — loads the stream once.
      await tester.tap(bubble);
      await tester.pump();
      expect(fakeAudio.playedUrls, [
        'https://example.com/recitation/001001.mp3',
      ]);

      // Pause mid-recitation...
      await tester.tap(bubble);
      await tester.pump();

      // ...and play again — must RESUME from the same spot, never
      // re-buffer the ayah from scratch.
      await tester.tap(bubble);
      await tester.pump();
      expect(fakeAudio.resumedCount, 1);
      expect(fakeAudio.playedUrls, hasLength(1));
    });

    testWidgets('a swipe fetches a brand-new ayah and shows it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      // Hermetic start: design pool only, so 112:1 is guaranteed fresh.
      QuranRepository.resetLivePoolForTest();
      addTearDown(QuranRepository.resetLivePoolForTest);
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        // A fresh random ayah (Al-Ikhlas 112:1) for every swipe request.
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'code': 200,
                'status': 'OK',
                'data': [
                  {
                    'edition': {'identifier': 'quran-uthmani'},
                    'text': 'قُلْ هُوَ اللَّهُ أَحَدٌ',
                    'numberInSurah': 1,
                    'surah': {'number': 112, 'englishName': 'Al-Ikhlas'},
                  },
                  {
                    'edition': {'identifier': 'en.sahih'},
                    'text': 'Say, "He is Allah, [who is] One,',
                  },
                ],
              }),
              200,
              // Explicit UTF-8 charset so the Arabic body string round-trips
              // — http defaults to latin1 without a JSON/charset type.
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDevineWordTheme(),
          home: AppStateScope(state: state, child: const HomeScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('AL-IKHLAS'), findsNothing);

      await tester.tap(find.text('Swipe up for another ayah'));
      await tester.pump();
      await tester.pump();

      // The freshly fetched ayah is now on screen.
      expect(find.text('AL-IKHLAS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsScreen — daily reminder', () {
    testWidgets(
      'toggle on reveals the reminder-time row and opens the picker',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final state = AppState(
          preferences: PreferencesService(
            await SharedPreferences.getInstance(),
          ),
        );
        // The test font (Ahem) renders every glyph as wide as it is tall,
        // which overflows the fixed 393px design-space rows; halving the
        // text scale makes the fake font fit like the real Inter does.
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDevineWordTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(0.5)),
                child: AppStateScope(
                  state: state,
                  child: const SettingsScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Off by default — no time row.
        expect(find.text('Reminder time'), findsNothing);

        // Turning the toggle on reveals the row with the default 8:00 AM.
        await tester.tap(find.text('Daily reminder'));
        await tester.pump();
        expect(find.text('Reminder time'), findsOneWidget);
        expect(find.text('8:00 AM'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Tapping the row opens the OS time picker (help text present).
        await tester.tap(find.text('Reminder time'));
        await tester.pumpAndSettle();
        expect(find.text('Set your daily reminder'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    test('reminder time persists and renders 12-hour labels', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      expect(state.reminderMinutes, 8 * 60);
      expect(reminderTimeLabel(state.reminderMinutes), '8:00 AM');

      await state.setReminderTime(19 * 60 + 45);
      final reloaded = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      expect(reloaded.reminderMinutes, 19 * 60 + 45);
      expect(reminderTimeLabel(reloaded.reminderMinutes), '7:45 PM');
    });
  });

  group('Appearance', () {
    test('persists and maps to the system ThemeMode', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      expect(state.appearanceMode, AppearanceMode.light);
      expect(state.themeMode, ThemeMode.light);

      await state.setAppearance(AppearanceMode.dark);
      expect(state.themeMode, ThemeMode.dark);

      final reloaded = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      expect(reloaded.appearanceMode, AppearanceMode.dark);
      expect(reloaded.themeMode, ThemeMode.dark);
    });

    testWidgets('dark theme restyles the settings screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
      );
      await state.setAppearance(AppearanceMode.dark);

      // 0.5 text scale so the wide Ahem test font fits the design rows.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDevineWordTheme(brightness: Brightness.light),
          darkTheme: buildDevineWordTheme(brightness: Brightness.dark),
          themeMode: state.themeMode,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(0.5)),
              child: AppStateScope(state: state, child: const SettingsScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      // The screen resolves the dark palette and its copy applies it.
      final titleContext = tester.element(find.text('Settings'));
      final palette = Theme.of(titleContext).extension<DwPalette>()!;
      expect(palette.background, DwPalette.dark.background);
      expect(palette.panel, DwPalette.dark.panel);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Test double for [AudioService] — records play requests without touching
/// the platform audio stack.
class _FakeAudioService extends AudioService {
  _FakeAudioService();

  final playedUrls = <String>[];
  int resumedCount = 0;
  bool _loaded = false;
  bool _playing = false;

  /// Set by tests to simulate which recitation the player has buffered.
  String? fakeLoadedUrl;
  final _states = StreamController<bool>.broadcast();

  @override
  bool get isPlaying => _playing;

  @override
  String? get loadedUrl => fakeLoadedUrl;

  @override
  Stream<bool> get stateStream => _states.stream;

  @override
  bool canResume(String url) => _loaded && !_playing;

  @override
  Future<void> play(String url) async {
    playedUrls.add(url);
    _loaded = true;
    _playing = true;
    _states.add(true);
  }

  @override
  Future<bool> resume() async {
    // Only count actual resumes — a resume attempt with nothing loaded
    // falls through to play() instead.
    if (!_loaded) return false;
    resumedCount++;
    _playing = true;
    _states.add(true);
    return true;
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _states.add(false);
  }

  @override
  Future<void> stop() async {
    _loaded = false;
    _playing = false;
    fakeLoadedUrl = null;
    _states.add(false);
  }
}

/// Test double for [RecitationTimingService] — serves fixed timings.
class _FakeTimingsService implements RecitationTimingService {
  _FakeTimingsService(this.timings);

  final List<AyahWordTiming>? timings;

  @override
  int get reciterId => RecitationTimingService.alafasyReciterId;

  @override
  Future<List<AyahWordTiming>?> forReference(String reference) async => timings;
}
