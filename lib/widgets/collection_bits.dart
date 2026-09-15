import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'dw_svg.dart';

/// Emblem + glass language button shared by the three photo screens.
/// Returns the widgets positioned for the 393x852 design space.
List<Widget> photoHeader({
  required String emblemAsset,
  required String globeAsset,
  required VoidCallback onLanguageTap,
}) {
  return [
    Positioned(
      left: 25,
      top: 62,
      width: 30,
      height: 30,
      child: DwSvg(emblemAsset),
    ),
    Positioned(
      right: 29,
      top: 59,
      width: 43,
      height: 43,
      child: Semantics(
        button: true,
        label: 'Language settings',
        child: GestureDetector(
          onTap: onLanguageTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Dw.white.withValues(alpha: 0.30),
              border: Border.all(color: Dw.white.withValues(alpha: 0.75)),
            ),
            child: DwSvg(globeAsset, width: 24, height: 24),
          ),
        ),
      ),
    ),
  ];
}

/// Glass search field shared by the Saved and Recent collection screens.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.searchAsset,
    required this.controller,
    required this.onChanged,
  });

  final String hint;
  final String searchAsset;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 21,
      right: 21,
      top: 201,
      height: 39,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Dw.white.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Dw.white.withValues(alpha: 0.75)),
          ),
          child: Row(
            children: [
              DwSvg(searchAsset, width: 22, height: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(fontSize: 13, color: Dw.searchGray),
                  cursorColor: Dw.searchGray,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Dw.searchGray,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 38px serif collection heading + 14px subtitle.
List<Widget> collectionHeader({
  required String title,
  required String subtitle,
}) {
  return [
    Positioned(
      left: 25,
      top: 127,
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: Dw.display,
          fontSize: 38,
          height: 1,
          letterSpacing: -0.5,
          color: Dw.collectionTitle,
        ),
      ),
    ),
    Positioned(
      left: 26,
      top: 171,
      child: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          letterSpacing: -0.25,
          color: Dw.subtitleBlue,
        ),
      ),
    ),
  ];
}
