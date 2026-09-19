import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devine_word/data/api_quran_repository.dart';
import 'package:devine_word/data/models.dart';
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
          client: MockClient(
            (request) async => http.Response('offline', 503),
          ),
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
    testWidgets(
      'long ayah at max text size flows without overflow',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        QuranRepository.resetLivePoolForTest();
        addTearDown(QuranRepository.resetLivePoolForTest);
        final state = AppState(
          preferences: PreferencesService(await SharedPreferences.getInstance()),
          // Deterministic offline fetch: swipes fall back to rotating the
          // built-in pool, exactly as on an offline device.
          apiRepository: ApiQuranRepository(
            client: MockClient(
              (request) async => http.Response('offline', 503),
            ),
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
      },
    );

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

    testWidgets('a swipe fetches a brand-new ayah and shows it', (tester) async {
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
          preferences: PreferencesService(await SharedPreferences.getInstance()),
        );
        // The test font (Ahem) renders every glyph as wide as it is tall,
        // which overflows the fixed 393px design-space rows; halving the
        // text scale makes the fake font fit like the real Inter does.
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDevineWordTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(0.5),
                ),
                child: AppStateScope(state: state, child: const SettingsScreen()),
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
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(0.5),
              ),
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
  bool _playing = false;
  final _states = StreamController<bool>.broadcast();

  @override
  bool get isPlaying => _playing;

  @override
  Stream<bool> get stateStream => _states.stream;

  @override
  Future<void> play(String url) async {
    playedUrls.add(url);
    _playing = true;
    _states.add(true);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _states.add(false);
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _states.add(false);
  }
}
