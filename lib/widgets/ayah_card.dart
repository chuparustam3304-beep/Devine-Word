import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'dw_svg.dart';

/// Glass ayah card used by Saved ayahs and Recent activity.
class AyahCard extends StatelessWidget {
  const AyahCard({
    super.key,
    required this.surahName,
    required this.reference,
    required this.arabic,
    this.time,
    this.bookmarkAsset,
    this.arabicSize = 26,
    this.height = 110,
  });

  final String surahName;
  final String reference;
  final String arabic;
  final String? time;
  final String? bookmarkAsset;
  final double arabicSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Dw.white.withValues(alpha: 0.29),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Dw.white.withValues(alpha: 0.66)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 11,
            right: 10,
            top: 10,
            height: 28,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                  decoration: BoxDecoration(
                    color: Dw.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    surahName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.3,
                      color: Dw.pillBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  reference,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Dw.collectionTitle,
                  ),
                ),
                if (time != null) ...[
                  const Spacer(),
                  Text(
                    time!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Dw.secondary,
                    ),
                  ),
                ],
                if (bookmarkAsset != null) ...[
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Dw.white.withValues(alpha: 0.88),
                    ),
                    child: DwSvg(bookmarkAsset!, width: 20, height: 20),
                  ),
                ] else if (time != null) ...[
                  const SizedBox(width: 6),
                  DwSvg(
                    'assets/07-recent-activity/chevron-right.svg',
                    width: 17,
                    height: 17,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 20,
            bottom: 24,
            child: Text(
              arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: Dw.arabic,
                fontSize: arabicSize,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Dw.arabicInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
