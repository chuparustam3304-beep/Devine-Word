import 'package:flutter/material.dart';

/// Design tokens transcribed from the design pack's
/// `assets/colors.css` and the per-screen `styles.css` values.
class Dw {
  Dw._();

  // --- colors.css ---------------------------------------------------------
  static const white = Color(0xFFFFFFFF);
  static const forest = Color(0xFF004638);
  static const sage = Color(0xFF386F59);
  static const ink = Color(0xFF111111);

  // --- screen-specific ----------------------------------------------------
  static const splashBg = Color(0xFFEADCCF);
  static const ayahGreen = Color(0xFF00513E);
  static const arabicBase = Color(0xFF101010);
  static const pageBg = Color(0xFFE9E9E9);

  // --- botanical homescreen pack (quran-reader, 603×1280) -------------------
  static const quranGreen = Color(0xFF1C5C48);
  static const quranPaper = Color(0xFFF6F4E7);
  /// The golden amber of the card's top-left botanical leaf — the accent
  /// the Previous/Next controls tint when pressed.
  static const leafAmber = Color(0xFFE8A040);

  // --- quranic onboarding prototype (440×956 design space) ----------------
  // Palette transcribed from quranic-onboarding-clone/styles.css `:root`.
  static const onboardingPaper = Color(0xFFF5EEDF); // --paper
  static const onboardingDeepGreen = Color(0xFF00483F); // --deep-green
  static const onboardingGold = Color(0xFFC9993F); // --gold
  /// `.ground` strip colour — kept as the reference for the cream shelf the
  /// grow screen no longer draws (regression-tested).
  static const onboardingGround = Color(0xFFF0DFB8);

  // --- typography.css -----------------------------------------------------
  static const ui = 'Inter';
  static const display = 'DM Serif Display';
  static const arabic = 'Noto Naskh Arabic';
  static const urdu = 'Noto Nastaliq Urdu';

  /// Reference artboard the HTML screens were designed against.
  static const designWidth = 393.0;
  static const designHeight = 852.0;

  /// Top edge of the grow screen's mountain artwork; the massif runs off
  /// the bottom of the 440×956 onboarding artboard.
  static const mountainTop = 554.0;
}
