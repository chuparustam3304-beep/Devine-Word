import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../routing/app_router.dart';
import '../state/app_state_scope.dart';
import '../widgets/ayah_card.dart';
import '../widgets/collection_bits.dart';
import '../data/models.dart' show ReadingRecord;
import '../widgets/dw_svg.dart';

/// Screen 07 — recent activity: real persisted reading events grouped by
/// day, with a working search over surah name and reference.
class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final q = _query.trim().toLowerCase();
    final records = state.recent
        .where(
          (r) =>
              q.isEmpty ||
              r.surahName.toLowerCase().contains(q) ||
              r.reference.contains(q),
        )
        .toList();
    final now = DateTime.now();
    final today = <_DayEntry>[];
    final yesterday = <_DayEntry>[];
    final earlier = <_DayEntry>[];
    for (final record in records) {
      final readAt = record.readAt;
      final isToday =
          readAt.year == now.year &&
          readAt.month == now.month &&
          readAt.day == now.day;
      final isYesterday =
          readAt.year == now.year &&
          readAt.month == now.month &&
          readAt.day == now.day - 1;
      final entry = _DayEntry(time: _formatTime(readAt), record: record);
      if (isToday) {
        today.add(entry);
      } else if (isYesterday) {
        yesterday.add(entry);
      } else {
        earlier.add(entry);
      }
    }

    return DwScreenFrame(
      background: Dw.photoFallback,
      body: (context) => Stack(
        children: [
          const DwCoverImage('assets/07-recent-activity/background.png'),
          ...photoHeader(
            emblemAsset: 'assets/07-recent-activity/emblem.svg',
            globeAsset: 'assets/07-recent-activity/globe.svg',
            onLanguageTap: () =>
                Navigator.of(context).pushNamed(Routes.settings),
          ),
          ...collectionHeader(
            title: 'Recent activity',
            subtitle: 'Return to the ayahs you’ve read.',
          ),
          SearchField(
            hint: 'Search recent ayahs',
            searchAsset: 'assets/07-recent-activity/search.svg',
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
          ),
          if (records.isEmpty)
            const Positioned(
              left: 25,
              right: 25,
              top: 300,
              child: Text(
                'No reading activity yet.\nAyahs you read will be listed here by day.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Dw.secondary),
              ),
            )
          else
            ..._dayGroups(today: today, yesterday: yesterday, earlier: earlier),
          BottomNavImage(
            asset: 'assets/07-recent-activity/nav.svg',
            onTap: (index) => switchTab(context, index),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime readAt) {
    final hour = readAt.hour % 12 == 0 ? 12 : readAt.hour % 12;
    final minute = readAt.minute.toString().padLeft(2, '0');
    final period = readAt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  List<Widget> _dayGroups({
    required List<_DayEntry> today,
    required List<_DayEntry> yesterday,
    required List<_DayEntry> earlier,
  }) {
    final widgets = <Widget>[];
    var top = 258.0;

    void day(String label) {
      widgets.add(
        Positioned(
          left: 25,
          top: top,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: Dw.display,
              fontSize: 18,
              color: Dw.collectionTitle,
            ),
          ),
        ),
      );
      top += 30;
    }

    void card(_DayEntry entry, {double size = 26}) {
      widgets.add(
        Positioned(
          left: 22,
          right: 22,
          top: top,
          child: AyahCard(
            surahName: entry.record.surahName,
            reference: entry.record.reference,
            arabic: entry.record.arabic,
            time: entry.time,
            arabicSize: size,
            height: 110,
          ),
        ),
      );
      top += 122;
    }

    if (today.isNotEmpty) {
      day('Today');
      for (final (index, entry) in today.indexed) {
        card(entry, size: index == 0 ? 26 : 24);
      }
    }
    if (yesterday.isNotEmpty) {
      day('Yesterday');
      for (final entry in yesterday) {
        card(entry);
      }
    }
    if (earlier.isNotEmpty && top < 560) {
      day('Earlier');
      for (final entry in earlier) {
        card(entry);
        if (top > 600) break;
      }
    }
    return widgets;
  }
}

class _DayEntry {
  const _DayEntry({required this.time, required this.record});

  final String time;
  final ReadingRecord record;
}
