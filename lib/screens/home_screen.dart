import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../widgets/collection_bits.dart';
import '../widgets/draggable_play_button.dart';
import '../widgets/dw_svg.dart';
import '../widgets/synced_ayah_text.dart';

/// Screen 05 — home feed: the daily ayah with its approved translation,
/// like/save/share rail, playback card and four-lobed bottom navigation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _poolIndex = 0;

  /// Text-size stepper: 0 = default, clamped to ±5 steps.
  /// Each step scales the on-screen font sizes by 10%.
  int _textStep = 0;
  static const int _maxTextStep = 5;

  /// Scrolls the ayah card back to the top when the ayah or text size changes.
  final ScrollController _ayahScroll = ScrollController();

  @override
  void dispose() {
    // TEMP-DEBUG
    debugPrint('DW-HOME-DISPOSE $hashCode\n${StackTrace.current}');
    _ayahScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // TEMP-DEBUG
    debugPrint('DW-HOME-INIT $hashCode');
  }

  void _scrollAyahToTop() {
    if (_ayahScroll.hasClients) {
      _ayahScroll.jumpTo(0);
    }
  }

  double get _fontScale => 1.0 + _textStep * 0.1;

  void _goTab(int index) => switchTab(context, index);

  /// Swipe-up handler: fetches a brand-new random ayah from the live API and
  /// shows it, so every swipe delivers fresh content beyond the pool loaded
  /// at launch. While a fetch is in flight, further swipes are ignored; when
  /// the fetch fails (e.g. offline) the pool already in memory keeps
  /// rotating so the user still gets a different ayah per swipe.
  void _nextAyah(AppState state) {
    if (state.isFetchingNextAyah) return;
    _advance(state);
  }

  Future<void> _advance(AppState state) async {
    final pool = state.repository.loadDailyPool();
    if (pool.isEmpty) return;
    final fetched = await state.fetchNextAyah();
    if (!mounted) return;
    setState(() {
      if (fetched) {
        // The fresh ayah was appended to the end of the pool — show it.
        _poolIndex = state.repository.loadDailyPool().length - 1;
      } else {
        // Offline fallback: keep advancing through what we already have.
        _poolIndex = (_poolIndex + 1) % state.repository.loadDailyPool().length;
      }
    });
    _scrollAyahToTop();
  }

  Future<void> _share(Ayah ayah) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${ayah.arabic}\n'
            '${ayah.surahName} ${ayah.reference} — Devine Word',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    // TEMP-DEBUG
    debugPrint('DW-HOME build loading=${state.isLoadingLiveData} '
        'pool=${state.repository.loadDailyPool().length} idx=$_poolIndex');
    if (state.isLoadingLiveData) {
      return DwScreenFrame(
        background: Dw.photoFallback,
        body: (context) => const Center(
          child: CircularProgressIndicator(color: Dw.homeBlue),
        ),
      );
    }
    final pool = state.repository.loadDailyPool();
    if (pool.isEmpty) {
      return DwScreenFrame(
        background: Dw.photoFallback,
        body: (context) => const Center(
          child: Text(
            'Live Quran data could not be loaded.\nPlease check your internet connection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Dw.secondary),
          ),
        ),
      );
    }
    final ayah = pool[_poolIndex % pool.length];
    final bookmarked = state.isBookmarked(ayah.reference);
    final translation = ayah.translationFor(state.translation);
    final isEnglish = state.translation == TranslationLanguage.english;
    final isBengali = state.translation == TranslationLanguage.bengali;
    final translationStyle = TextStyle(
      fontFamily: isEnglish ? Dw.ui : (isBengali ? Dw.bengali : Dw.urdu),
      fontSize: (isEnglish ? 16 : 21) * _fontScale,
      height: isEnglish ? 1.5 : 2.0,
      fontWeight: FontWeight.w500,
      color: Dw.homeBlue,
    );

    return DwScreenFrame(
      background: Dw.photoFallback,
      body: (context) => Stack(
        children: [
          const DwCoverImage('assets/05-home/background.png'),
          ...photoHeader(
            emblemAsset: 'assets/05-home/emblem.svg',
            globeAsset: 'assets/05-home/globe.svg',
            onLanguageTap: () =>
                Navigator.of(context).pushNamed(Routes.settings),
          ),
          Positioned(
            left: 18,
            top: 141,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 6, 10, 5),
                  decoration: BoxDecoration(
                    color: Dw.white.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ayah.surahName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2,
                      color: Dw.homeBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Text(
                  ayah.reference,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: Dw.homeBlue,
                  ),
                ),
              ],
            ),
          ),
          // Ayah block — full-width glass card (left/right 25, white 31%
          // fill, 86% border). Fixed default height (181→543) for short
          // ayat, but it GROWS DOWNWARD with the ayah's length — the top
          // edge never moves — up to 534px tall (bottom edge 715, 8px
          // above the swipe strip); beyond that the content scrolls
          // inside the card.
          Positioned(
            top: 181,
            left: 25,
            right: 25,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 20, 6, 6),
              decoration: BoxDecoration(
                color: Dw.white.withValues(alpha: 0.31),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Dw.white.withValues(alpha: 0.86)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scroll viewport: a 283px minimum keeps the card at
                  // its default 362px height for short ayat; the viewport
                  // then grows with the content up to 455px (card bottom
                  // at 715, just above the swipe strip), and only beyond
                  // that does the content scroll. (Card chrome totals
                  // 79px: bottom padding 6 + bar margins 10/12 + 51px
                  // bar.)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 283,
                      maxHeight: 455,
                    ),
                    child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.dragged)
                        ? Dw.homeBlue
                        : Dw.homeBlue.withValues(alpha: 0.45),
                  ),
                  thickness: WidgetStateProperty.all(3),
                  radius: const Radius.circular(3),
                  minThumbLength: 40,
                ),
                child: Scrollbar(
                  controller: _ayahScroll,
                  thumbVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                  controller: _ayahScroll,
                  key: ValueKey(ayah.reference),
                  // Left 13 + card padding 6 = 19px inset (text at x≈44,
                  // as before). Symmetric right inset — the Like/Save/
                  // Share rail now lives pinned at the card's bottom.
                  padding: const EdgeInsets.only(left: 13, right: 13),
                  child: Column(
                    children: [
                      SyncedAyahText(
                        arabic: ayah.arabic,
                        reference: ayah.reference,
                        audioUrl: ayah.recitationUrl,
                        style: TextStyle(
                          fontFamily: Dw.arabic,
                          fontSize: 43 * _fontScale,
                          height: 1.55,
                          fontWeight: FontWeight.w700,
                          color: Dw.ayahGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 45,
                        height: 1,
                        color: Dw.ayahGreen.withValues(alpha: 0.32),
                      ),
                      const SizedBox(height: 19),
                      Text(
                        translation,
                        textDirection:
                            isEnglish ? TextDirection.ltr : TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: translationStyle,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                ),
                    ),
                  ),
                  // Like / Save / Share — horizontal action bar pinned
                  // to the bottom of the card (outside the scroll view,
                  // so it never scrolls away). One shared solid-white
                  // capsule behind the whole bar; outer padding = margin
                  // from the card's edges, inner padding keeps the three
                  // space-between buttons off the bar's edges.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Dw.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _HomeAction(
                            asset: 'assets/05-home/heart.svg',
                            label: 'Like',
                            onTap: () => state.toggleLike(ayah.reference),
                          ),
                          _HomeAction(
                            asset: bookmarked
                                ? 'assets/06-saved-ayahs/bookmark-filled.svg'
                                : 'assets/05-home/bookmark.svg',
                            label: 'Save',
                            onTap: () => state.toggleBookmark(ayah.reference),
                          ),
                          _HomeAction(
                            asset: 'assets/05-home/share.svg',
                            label: 'Share',
                            onTap: () => _share(ayah),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 29,
            top: 141,
            child: Row(
              children: [
                _TextStepButton(
                  icon: Icons.add,
                  semanticLabel: 'Increase text size',
                  enabled: _textStep < _maxTextStep,
                  onTap: () => setState(() {
                    _textStep =
                        (_textStep + 1).clamp(-_maxTextStep, _maxTextStep);
                    _scrollAyahToTop();
                  }),
                ),
                const SizedBox(width: 12),
                _TextStepButton(
                  icon: Icons.remove,
                  semanticLabel: 'Decrease text size',
                  enabled: _textStep > -_maxTextStep,
                  onTap: () => setState(() {
                    _textStep =
                        (_textStep - 1).clamp(-_maxTextStep, _maxTextStep);
                    _scrollAyahToTop();
                  }),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 94,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _nextAyah(state),
              // A genuine upward flick counts as a swipe too, not just a tap.
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < 0) _nextAyah(state);
              },
              child: Column(
                children: [
                  const Text(
                    '⌃',
                    style: TextStyle(
                      fontSize: 25,
                      height: 0.72,
                      fontWeight: FontWeight.w300,
                      color: Dw.homeBlue,
                    ),
                  ),
                  Text(
                    state.isFetchingNextAyah
                        ? 'Fetching a new ayah…'
                        : 'Swipe up for another ayah',
                    style: const TextStyle(fontSize: 12, color: Dw.homeBlue),
                  ),
                ],
              ),
            ),
          ),
          BottomNavImage(asset: 'assets/05-home/nav.svg', onTap: _goTab),
          // Floating play/pause bubble — draggable anywhere on the
          // screen (clamped to stay fully visible). Initial spot: left
          // 25px card inset, bottom edge 8px above the swipe strip
          // (strip top ≈723 → 60px bubble parked at top 655). Last in
          // the stack so its gestures win wherever it is dragged.
          DraggablePlayButton(
            initialPosition: const Offset(25, 655),
            audioUrl: ayah.recitationUrl,
          ),
        ],
      ),
    );
  }
}

/// Glass circle text-size stepper button, styled after the globe button.
class _TextStepButton extends StatelessWidget {
  const _TextStepButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? Dw.homeBlue : Dw.homeBlue.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Dw.white.withValues(alpha: 0.30),
            border: Border.all(color: Dw.white.withValues(alpha: 0.75)),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

/// One labelled icon control in the home action rail.
class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DwSvg(asset, width: 27, height: 27),
      ),
    );
  }
}
