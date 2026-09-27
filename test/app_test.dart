import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
import 'package:devine_word/routing/app_router.dart';
import 'package:devine_word/screens/home_screen.dart';
import 'package:devine_word/screens/onboarding_grow_screen.dart';
import 'package:devine_word/screens/onboarding_journey_screen.dart';
import 'package:devine_word/screens/onboarding_quran_screen.dart';
import 'package:devine_word/screens/splash_screen.dart';
import 'package:devine_word/services/audio_service.dart';
import 'package:devine_word/services/preferences_service.dart';
import 'package:devine_word/state/app_state.dart';
import 'package:devine_word/state/app_state_scope.dart';
import 'package:devine_word/widgets/dw_svg.dart';
import 'package:devine_word/widgets/onboarding_bits.dart';
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

    /// The stroke paint of a span, when it carries one — the recited-word
    /// highlight is a stroke outline, never a background container.
    Paint? strokePaintOf(InlineSpan span) {
      if (span is! TextSpan) return null;
      final paint = span.style?.foreground;
      return paint?.style == PaintingStyle.stroke ? paint : null;
    }

    /// True when the span paints the recited-word highlight: a green
    /// (`Dw.ayahGreen`) stroke outline.
    bool isGreenStroke(InlineSpan span) {
      final color = strokePaintOf(span)?.color;
      return color != null && color.toARGB32() == Dw.ayahGreen.toARGB32();
    }

    /// Every span of the ayah's rich text, across all rendered passes.
    List<TextSpan> spansOf(WidgetTester tester) => tester
        .widgetList(
          find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
        )
        .expand((w) {
          final root = (w as Text).textSpan;
          return root is TextSpan
              ? (root.children ?? const <InlineSpan>[])
              : const <InlineSpan>[];
        })
        .whereType<TextSpan>()
        .toList();

    /// The recited word is marked by a green stroke outline (`Dw.ayahGreen`
    /// via `TextStyle.foreground` with `PaintingStyle.stroke`); the rest of
    /// the ayah keeps the default ink colour (`Dw.arabicBase` / caller color).
    /// No span should use a background fill (container highlight).
    int greenSpanCount(WidgetTester tester) =>
        spansOf(tester).where(isGreenStroke).length;

    /// Spans still carrying a painted background — the container highlight
    /// this widget must no longer use.
    int backgroundSpanCount(WidgetTester tester) =>
        spansOf(tester).where((span) => span.style?.background != null).length;

    /// Spans carrying a painted stroke outline — the active highlight
    /// approach. Should match [greenSpanCount] since only green strokes are
    /// used.
    int strokedSpanCount(WidgetTester tester) =>
        spansOf(tester).where((span) => strokePaintOf(span) != null).length;

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
      final green = spansOf(tester)
          .where(isGreenStroke)
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
        final allSpans = spansOf(tester);

        // The recited word is 'ثَانِيَةٌ' (mid-way through word 2) and it is
        // emphasised with a green stroke outline via `foreground` paint.
        final recitedWord = allSpans.firstWhere(
          (span) => span.text == 'ثَانِيَةٌ',
        );
        expect(recitedWord.style?.color, isNull);
        final paint = strokePaintOf(recitedWord);
        expect(paint, isNotNull);
        expect(paint?.color.toARGB32(), Dw.ayahGreen.toARGB32());

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
    test('onboarding completion persists', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = PreferencesService(
        await SharedPreferences.getInstance(),
      );
      final state = AppState(preferences: preferences);
      expect(state.onboardingComplete, isFalse);
      await state.completeOnboarding();
      expect(AppState(preferences: preferences).onboardingComplete, isTrue);
    });

    test('daily pool keeps offline content on network failure', () async {
      SharedPreferences.setMockInitialValues({});
      QuranRepository.resetLivePoolForTest();
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async => http.Response('offline', 503)),
        ),
      );
      final before = state.repository.loadDailyPool();
      await state.loadLiveData();
      expect(state.repository.loadDailyPool(), before);
      expect(state.isLoadingLiveData, isFalse);
      expect(state.liveDataError, isNotNull);
    });
  });

  group('DevineWordApp', () {
    testWidgets('boots the shell without exceptions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      QuranRepository.resetLivePoolForTest();
      addTearDown(QuranRepository.resetLivePoolForTest);
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        // Deterministic offline behaviour, exactly as on an offline device.
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async => http.Response('offline', 503)),
        ),
      );
      await tester.pumpWidget(DevineWordApp(state: state));
      // First frame plus the splash brand-moment window.
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      // The launch surface (splash loader or the home ayah card, depending
      // on the splash-routing development switch) must render content — it
      // must never strand the app on an empty frame.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Navigator), findsOneWidget);
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('resolves each onboarding route to its screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      QuranRepository.resetLivePoolForTest();
      addTearDown(QuranRepository.resetLivePoolForTest);
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async => http.Response('offline', 503)),
        ),
      );
      await tester.pumpWidget(DevineWordApp(state: state));
      await tester.pump();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      // Walks the onboarding sequence in flow order.
      for (final (route, screen) in <(String, Type)>[
        (Routes.onboardingGrow, OnboardingGrowScreen),
        (Routes.onboardingJourney, OnboardingJourneyScreen),
        (Routes.onboardingQuranic, OnboardingQuranScreen),
      ]) {
        navigator.pushNamed(route);
        await tester.pump();
        // Let the page transition finish so the new screen is on top.
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.byType(screen), findsOneWidget, reason: route);
      }
      expect(tester.takeException(), isNull);
    });
  });

  // (The player-card test was removed with the card itself; the
  group('Onboarding — quranic prototype screens', () {
    /// Pumps a shell with the three onboarding routes registered (mirroring
    /// `main.dart`'s route table) and opens [initialRoute], so the
    /// Continue/Back controls can really navigate.
    Future<AppState> pumpOnboarding(
      WidgetTester tester,
      String initialRoute,
    ) async {
      SharedPreferences.setMockInitialValues({});
      QuranRepository.resetLivePoolForTest();
      addTearDown(QuranRepository.resetLivePoolForTest);
      final state = AppState(
        preferences: PreferencesService(await SharedPreferences.getInstance()),
        apiRepository: ApiQuranRepository(
          client: MockClient((request) async => http.Response('offline', 503)),
        ),
      );
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            theme: buildDevineWordTheme(),
            initialRoute: initialRoute,
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => switch (settings.name) {
                // '/' is both the splash route and the inert base route that
                // MaterialApp seeds for a non-'/' initialRoute — only build
                // the real splash when it is the route actually being opened,
                // otherwise its brand-moment timer is left pending.
                Routes.splash when initialRoute == Routes.splash =>
                  const SplashScreen(),
                Routes.onboardingGrow => const OnboardingGrowScreen(),
                Routes.onboardingJourney => const OnboardingJourneyScreen(),
                Routes.onboardingQuranic => const OnboardingQuranScreen(),
                Routes.home => const HomeScreen(),
                _ => const OnboardingJourneyScreen(),
              },
            ),
          ),
        ),
      );
      await tester.pump();
      return state;
    }

    testWidgets('splash sends an incomplete onboarding to step 1 (grow)', (
      tester,
    ) async {
      await pumpOnboarding(tester, Routes.splash);

      // The splash gives the brand mark its moment, then routes onward.
      await tester.pump(const Duration(milliseconds: 1300));
      // Don't use pumpAndSettle() because the grow screen has infinite spin
      // animations that never settle.
      await tester.pump(const Duration(milliseconds: 1000));

      // Step 1 is the grow screen — onboarding always starts there.
      expect(find.byType(OnboardingGrowScreen), findsOneWidget);
      expect(find.byType(OnboardingJourneyScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grow screen is step 1 and continues to the journey screen', (
      tester,
    ) async {
      await pumpOnboarding(tester, Routes.onboardingGrow);

      expect(
        find.text('Grow closer\nto GOD\na little more\neveryday'),
        findsOneWidget,
      );
      expect(find.text('Audio devotionals'), findsOneWidget);
      expect(find.text('Private reflections'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Continue swaps step 1 for step 2 (no back stack).
      await tester.tap(find.text('Continue'));
      // Wait for navigation to complete. Use multiple pumps to ensure
      // the transition finishes.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Every journey of\nfaith is unique'), findsOneWidget);
      expect(find.byType(OnboardingGrowScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grow screen slides the mountain up onto the bottom edge', (
      tester,
    ) async {
      // The massif is anchored at .mountain-art's top (554) and scaled to
      // cover the rest of the frame, so it runs off the bottom edge with the
      // Continue button sitting on the mountain rather than on a cream shelf.
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpOnboarding(tester, Routes.onboardingGrow);

      final mountain = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName.endsWith('mountain.png'),
      );
      expect(mountain, findsOneWidget);

      // 1:1 mapping between design pixels and the 440x956 test surface.
      // Landing: the whole range is still parked under the bottom edge, one
      // box height below its seat, so nothing of it shows yet.
      final landing = tester.getRect(mountain);
      expect(landing.top, 956); // the summit starts below the fold
      expect(landing.bottom, 956 + (956 - 554));

      // Mid-rise it is part-way up: the summit has cleared the bottom edge but
      // has not reached .mountain-art's line.
      await tester.pump(const Duration(milliseconds: 420));
      final rising = tester.getRect(mountain);
      expect(rising.top, lessThan(956));
      expect(rising.top, greaterThan(554));

      // Past the end of its window it seats exactly on the 554px line, with
      // the offset resolved to a hard zero rather than a near-miss.
      await tester.pump(const Duration(milliseconds: 500));
      final rect = tester.getRect(mountain);
      expect(rect.left, 0); // full-bleed
      expect(rect.width, 440);
      expect(rect.top, 554); // .mountain-art top
      expect(rect.bottom, 956); // runs off the bottom edge
      // `cover` is what actually gets it there: a 737x455 source in a 440x402
      // box scales by 402/455, so it fills the box top-to-bottom and sheds the
      // outer flanks at the sides. `fitWidth` would instead leave the massif
      // 271.6px tall, stopping 130px short of the bottom edge.
      final art = tester.widget<Image>(mountain);
      expect(art.fit, BoxFit.cover);
      expect(art.alignment, Alignment.topCenter);
      // No cream shelf underneath any more.
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == Dw.onboardingGround,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'grow screen intro fades the headline in clearly, falls the leaf '
      'from above, and spins the flowers',
      (tester) async {
        // 1:1 mapping between design pixels and the test surface.
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpOnboarding(tester, Routes.onboardingGrow);

        final title = find.text('Grow closer\nto GOD\na little more\neveryday');
        final leaf = find.byWidgetPredicate(
          (widget) =>
              widget is DwSvg && widget.asset.endsWith('leaf-orange.svg'),
        );
        final blooms = find.byWidgetPredicate(
          (widget) =>
              widget is DwSvg && widget.asset.endsWith('flower-yellow.svg'),
        );
        double titleOpacity() {
          final op = tester
              .widget<Opacity>(
                find.ancestor(of: title, matching: find.byType(Opacity)).first,
              )
              .opacity;
          return op;
        }

        double leafOpacity() => tester
            .widget<Opacity>(
              find.ancestor(of: leaf, matching: find.byType(Opacity)).first,
            )
            .opacity;

        // Landing: the title is at its rest position (185) but heavily blurred
        // and nearly invisible. The leaf has not appeared yet.
        expect(tester.getRect(title).top, 185);
        expect(
          titleOpacity(),
          lessThan(0.1),
        ); // heavily blurred = nearly invisible
        expect(leafOpacity(), 0);

        // After 700ms the title should be clearing up (blur decreasing, opacity increasing).
        await tester.pump(const Duration(milliseconds: 700));
        expect(
          tester.getRect(title).top,
          185,
        ); // still at rest position (no slide)
        expect(titleOpacity(), greaterThan(0.5)); // becoming visible
        expect(leafOpacity(), 0); // leaf hasn't started falling yet

        // Leaf starts falling at 0.50 of intro (2800ms * 0.50 = 1400ms).
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.getRect(title).top, 185);
        expect(titleOpacity(), greaterThan(0.9)); // nearly clear
        expect(leafOpacity(), 0); // still not fallen

        // Leaf starts falling. Pump a bit more to see it appear.
        await tester.pump(const Duration(milliseconds: 200));
        // At 1600ms (0.57 of intro), leaf should be visible and falling.
        expect(leafOpacity(), greaterThan(0));
        // Leaf should be above its rest position (coming down from above).
        expect(tester.getTopLeft(leaf).dy, lessThan(114));

        // By the end of intro (2800ms), leaf has settled at rest.
        await tester.pump(const Duration(milliseconds: 1200));
        expect(leafOpacity(), greaterThan(0.99));
        // Leaf should be at its rest position (114).
        expect(tester.getTopLeft(leaf).dy, moreOrLessEquals(114, epsilon: 2.0));

        // Flowers appear after 0.7 of intro (1960ms) and spin continuously.
        // Pump more time for them to appear and spin.
        await tester.pump(const Duration(milliseconds: 400));
        expect(blooms, findsNWidgets(2));
        // Both flowers should be visible.
        final firstRect = tester.getRect(blooms.at(0));
        final secondRect = tester.getRect(blooms.at(1));
        // First flower should be in the right area of the screen.
        expect(firstRect.center.dx, greaterThan(340));
        expect(firstRect.center.dx, lessThan(400));
        expect(firstRect.center.dy, greaterThan(230));
        expect(firstRect.center.dy, lessThan(280));
        // Second flower should be on the left side.
        expect(secondRect.center.dx, greaterThan(10));
        expect(secondRect.center.dx, lessThan(70));
        expect(secondRect.center.dy, greaterThan(360));
        expect(secondRect.center.dy, lessThan(420));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('grow screen lands settled when animations are disabled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await pumpOnboarding(tester, Routes.onboardingGrow);

      // `prefers-reduced-motion`: straight to the settled screen.
      expect(
        tester
            .getRect(find.text('Grow closer\nto GOD\na little more\neveryday'))
            .top,
        185,
      );
      expect(
        tester.getTopLeft(
          find.byWidgetPredicate(
            (widget) =>
                widget is DwSvg && widget.asset.endsWith('leaf-orange.svg'),
          ),
        ),
        const Offset(157, 114),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('journey screen is step 2 and continues to the ayah screen', (
      tester,
    ) async {
      await pumpOnboarding(tester, Routes.onboardingJourney);

      expect(find.text('Every journey of\nfaith is unique'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      // Don't use pumpAndSettle() because the grow screen has infinite spin
      // animations that never settle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(
          'Everyday a new\nQuranic Ayah with\nRecitation & Translation',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('journey screen back disc sits left of the CTA and goes back', (
      tester,
    ) async {
      // 1:1 mapping between design pixels and the test surface.
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpOnboarding(tester, Routes.onboardingJourney);

      // The pale disc pairs with the CTA on the same bottom row.
      final back = find.bySemanticsLabel('Back');
      expect(back, findsOneWidget);
      final backRect = tester.getRect(back);
      final ctaRect = tester.getRect(find.byType(OnboardingContinueButton));
      expect(backRect.size, const Size(57, 57)); // matches the CTA's height
      expect(backRect.left, 27); // anchors the row
      expect(backRect.top, 838); // .screen-journey .continue-button bottom: 61
      expect(ctaRect.left, 96); // 27 + 57 disc + 12 gap
      expect(ctaRect.width, 317); // 386 - 57 disc - 12 gap
      expect(backRect.center.dy, moreOrLessEquals(ctaRect.center.dy));
      final disc = tester.widget<DwSvg>(
        find.descendant(of: back, matching: find.byType(DwSvg)),
      );
      expect(disc.asset, 'assets/09-onboarding/back-arrow.svg');

      // Back returns to step 1 (grow).
      await tester.tap(back);
      // Pump enough time for the navigation to complete.
      // Don't use pumpAndSettle() because the grow screen has infinite spin
      // animations that never settle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Grow closer\nto GOD\na little more\neveryday'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('quran screen shows screen 3 and finishes onboarding home', (
      tester,
    ) async {
      final state = await pumpOnboarding(tester, Routes.onboardingQuranic);

      expect(
        find.text(
          'Everyday a new\nQuranic Ayah with\nRecitation & Translation',
        ),
        findsOneWidget,
      );
      // The four approved ayat, each with its rosette and book badge.
      expect(
        find.text('اقْرَأْ بِاسْمِ رَبِّكَ الَّذِي خَلَقَ'),
        findsOneWidget,
      );
      expect(
        find.text('وَمَا خَلَقْتُ الْجِنَّ وَالْإِنسَ إِلَّا لِيَعْبُدُونِ'),
        findsOneWidget,
      );
      expect(
        find.text('إِنَّ هَٰذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ'),
        findsOneWidget,
      );
      expect(find.text('وَقُل رَّبِّ زِدْنِي عِلْمًا'), findsOneWidget);
      final assets = tester
          .widgetList<DwSvg>(find.byType(DwSvg))
          .map((svg) => svg.asset)
          .toList();
      expect(assets.where((a) => a.endsWith('book-badge.svg')), hasLength(4));
      expect(
        assets.where((a) => a.endsWith('verse-rosette.svg')),
        hasLength(4),
      );
      expect(assets, contains('assets/09-onboarding/moon.svg'));
      expect(assets, contains('assets/09-onboarding/back-arrow.svg'));
      expect(tester.takeException(), isNull);

      // Continue completes onboarding and opens home.
      expect(state.onboardingComplete, isFalse);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.onboardingComplete, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quran screen back disc mirrors step 2 and returns to it', (
      tester,
    ) async {
      // 1:1 mapping between design pixels and the test surface.
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpOnboarding(tester, Routes.onboardingQuranic);

      // The prototype floats a bare arrow at the frame's top-left; this step
      // now pairs the same pale disc with its CTA on the bottom row, exactly
      // like step 2.
      final back = find.bySemanticsLabel('Back');
      expect(back, findsOneWidget);
      final backRect = tester.getRect(back);
      final ctaRect = tester.getRect(find.byType(OnboardingContinueButton));
      expect(backRect.size, const Size(55, 55)); // matches the CTA's height
      expect(backRect.left, 27); // the row anchor step 2's disc uses
      expect(backRect.top, 815); // .quran-button — bottom: 86px
      expect(ctaRect.left, 94); // 27 + 55 disc + 12 gap
      expect(ctaRect.right, 393); // the prototype's 47 + 346 right edge
      expect(backRect.center.dy, moreOrLessEquals(ctaRect.center.dy));
      expect(backRect.top, greaterThan(400)); // nothing left at the top
      final disc = tester.widget<DwSvg>(
        find.descendant(of: back, matching: find.byType(DwSvg)),
      );
      expect(disc.asset, 'assets/09-onboarding/back-arrow.svg');

      // Back returns to step 2 (journey).
      await tester.tap(back);
      // Don't use pumpAndSettle() because the grow screen has infinite spin
      // animations that never settle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Every journey of\nfaith is unique'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test(
      'back disc glyph is centred in the disc and slightly smaller',
      () async {
        final svg = await File('assets/09-onboarding/back-arrow.svg')
            .readAsString();

        // A 48-unit viewBox with a full-bleed r=24 disc at (24, 24).
        expect(svg, contains('<circle cx="24" cy="24" r="24"'));
        expect(svg, contains('stroke-width="2.6"'));

        // Ink bounds of the arrow path, 2.6 stroke and round caps included.
        final path = RegExp(r'd="([^"]+)"').firstMatch(svg)!.group(1)!;
        final bounds = _strokeInkBounds(path, 2.6);
        expect(bounds.center.dx, moreOrLessEquals(24, epsilon: 0.01));
        expect(bounds.center.dy, moreOrLessEquals(24, epsilon: 0.01));
        expect(bounds.width, moreOrLessEquals(bounds.height, epsilon: 0.01));
        // 18.6 units wide — 39% of the disc, a touch less than the 20.2x22.2
        // the delivered asset drew 3.7 units right of centre.
        expect(bounds.width, greaterThan(0.35 * 48));
        expect(bounds.width, lessThan(0.40 * 48));
      },
    );
  });

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

      // The supplied Next control replaces swipe-to-advance. Each press
      // slides the top card off the deck; the verse only commits once the
      // slide settles.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel('Next ayah'));
        await tester.pump(); // start the deck slide
        await tester.pump(const Duration(milliseconds: 450)); // let it settle
      }
      expect(find.text('AL-BAQARAH'), findsOneWidget);

      // Max out the text-size stepper (5 presses).
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('Increase reading size'));
        await tester.pump();
      }
      await tester.pump();

      // The ayah block must reflow/scale down — never paint an overflow
      // banner or collide with the player card.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'fixed botanical play control toggles and removed features stay absent',
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

        final play = find.bySemanticsLabel('Play recitation');
        expect(play, findsOneWidget);
        final rect = tester.getRect(play);
        await tester.tap(play);
        await tester.pump();
        expect(find.bySemanticsLabel('Pause recitation'), findsOneWidget);
        expect(
          fakeAudio.playedUrls.single,
          'https://example.com/recitation/001001.mp3',
        );
        await tester.tap(find.bySemanticsLabel('Pause recitation'));
        await tester.pump();
        expect(play, findsOneWidget);
        await tester.drag(play, const Offset(200, 0));
        await tester.pump();
        expect(tester.getRect(play), rect);
        for (final label in [
          'Like',
          'Save',
          'Settings',
          'Recent activity',
          'Swipe up for another ayah',
        ]) {
          expect(find.text(label), findsNothing);
        }
        expect(find.bySemanticsLabel('Share ayah'), findsOneWidget);
        expect(tester.takeException(), isNull);
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

      final bubble = find.bySemanticsLabel(
        RegExp(r'^(Play|Pause) recitation$'),
      );

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

    testWidgets(
      'buttons navigate, swiping does not, and language changes live text',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        QuranRepository.resetLivePoolForTest();
        addTearDown(QuranRepository.resetLivePoolForTest);
        final audio = _FakeAudioService();
        AudioService.instance = audio;
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
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next ayah'));
        await tester.pumpAndSettle();
        expect(find.text('AR-RA’D'), findsOneWidget);
        await tester.drag(find.byType(SyncedAyahText), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(find.text('AR-RA’D'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Previous ayah'));
        await tester.pumpAndSettle();
        expect(find.text('ASH-SHARH'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Translation language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('English · English'));
        await tester.pumpAndSettle();
        expect(find.text('Indeed, with hardship comes ease.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
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
    fakeLoadedUrl = url;
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

/// Ink bounds — where the strokes actually land — of a `M`/`L`/`H`/`V` path,
/// including [strokeWidth] and its round caps and joins. Used to prove the
/// onboarding back-arrow glyph is centred inside its disc and inset from it.
Rect _strokeInkBounds(String d, double strokeWidth) {
  final tokens = RegExp(r'[MmLlHhVvZz]|-?\d*\.?\d+')
      .allMatches(d)
      .map((match) => match.group(0)!)
      .toList();
  final points = <Offset>[];
  var cursor = Offset.zero;
  var command = '';
  var index = 0;
  double operand() => double.parse(tokens[index++]);

  while (index < tokens.length) {
    final token = tokens[index];
    if (RegExp(r'[A-Za-z]').hasMatch(token)) {
      command = token;
      index++;
      continue;
    }
    switch (command) {
      case 'M' || 'm':
        final x = operand();
        final y = operand();
        cursor = command == 'M' ? Offset(x, y) : cursor + Offset(x, y);
        points.add(cursor);
        command = command == 'M' ? 'L' : 'l'; // extra pairs are linetos
      case 'L' || 'l':
        final x = operand();
        final y = operand();
        cursor = command == 'L' ? Offset(x, y) : cursor + Offset(x, y);
        points.add(cursor);
      case 'H' || 'h':
        final x = operand();
        cursor = Offset(command == 'H' ? x : cursor.dx + x, cursor.dy);
        points.add(cursor);
      case 'V' || 'v':
        final y = operand();
        cursor = Offset(cursor.dx, command == 'V' ? y : cursor.dy + y);
        points.add(cursor);
      default:
        index++; // Unsupported command: drop its operand.
    }
  }

  final half = strokeWidth / 2;
  final xs = points.map((point) => point.dx);
  final ys = points.map((point) => point.dy);
  return Rect.fromLTRB(
    xs.reduce(math.min) - half,
    ys.reduce(math.min) - half,
    xs.reduce(math.max) + half,
    ys.reduce(math.max) + half,
  );
}
