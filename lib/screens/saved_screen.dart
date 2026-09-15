import 'package:flutter/material.dart';

import '../data/models.dart';
import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../state/app_state_scope.dart';
import '../widgets/ayah_card.dart';
import '../widgets/collection_bits.dart';
import '../widgets/dw_svg.dart';

/// Screen 06 — saved ayahs: the user's live bookmarks with a working
/// search over surah name, reference and Arabic text.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Newest bookmark first, filtered by the search query.
  List<Ayah> _visibleSaved() {
    final state = AppStateScope.of(context);
    final repository = state.repository;
    final saved = state.bookmarks
        .map(repository.findByReference)
        .whereType<Ayah>()
        .toList()
        .reversed
        .toList();
    if (_query.trim().isEmpty) return saved;
    final q = _query.trim().toLowerCase();
    return saved
        .where(
          (a) =>
              a.surahName.toLowerCase().contains(q) ||
              a.reference.contains(q) ||
              a.arabic.contains(_query.trim()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final saved = _visibleSaved();
    final totalCount = AppStateScope.of(context).bookmarks.length;
    return DwScreenFrame(
      background: Dw.photoFallback,
      body: (context) => Stack(
        children: [
          const DwCoverImage('assets/06-saved-ayahs/background.png'),
          ...photoHeader(
            emblemAsset: 'assets/06-saved-ayahs/emblem.svg',
            globeAsset: 'assets/06-saved-ayahs/globe.svg',
            onLanguageTap: () =>
                Navigator.of(context).pushNamed(Routes.settings),
          ),
          ...collectionHeader(
            title: 'Saved ayahs',
            subtitle: 'Keep the words that stay with you.',
          ),
          SearchField(
            hint: 'Search saved ayahs',
            searchAsset: 'assets/06-saved-ayahs/search.svg',
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
          ),
          Positioned(
            left: 25,
            right: 27,
            top: 258,
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalCount saved ayah${totalCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Dw.collectionTitle,
                  ),
                ),
                const Text(
                  'Newest first',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Dw.refBlue,
                  ),
                ),
              ],
            ),
          ),
          if (saved.isEmpty)
            const Positioned(
              left: 25,
              right: 25,
              top: 300,
              child: Text(
                'Ayahs you save will appear here.\nTap Save on the home screen to keep one.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Dw.secondary),
              ),
            )
          else
            ..._savedCards(saved),
          BottomNavImage(
            asset: 'assets/06-saved-ayahs/nav.svg',
            onTap: (index) => switchTab(context, index),
          ),
        ],
      ),
    );
  }

  List<Widget> _savedCards(List<Ayah> saved) {
    final cards = <Widget>[];
    var top = 288.0;
    for (final (index, ayah) in saved.indexed) {
      cards.add(
        Positioned(
          left: 22,
          right: 22,
          top: top,
          child: AyahCard(
            surahName: ayah.surahName,
            reference: ayah.reference,
            arabic: ayah.arabic,
            arabicSize: index == 0 ? 27 : 24,
            height: index == 0 ? 122 : 116,
            bookmarkAsset: 'assets/06-saved-ayahs/bookmark-filled.svg',
          ),
        ),
      );
      top += index == 0 ? 132 : 125;
      if (top > 600) break;
    }
    return cards;
  }
}
