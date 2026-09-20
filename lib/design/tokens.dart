import 'package:flutter/material.dart';

/// Design tokens transcribed from the design pack's
/// `assets/colors.css` and the per-screen `styles.css` values.
class Dw {
  Dw._();

  // --- colors.css ---------------------------------------------------------
  static const white = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFCFBF8);
  static const settingsPanel = Color(0xFFF7F7F7);
  static const forest = Color(0xFF004638);
  static const forestDeep = Color(0xFF083B2C);
  static const navSelected = Color(0xFF306048);
  static const sage = Color(0xFF386F59);
  static const green = Color(0xFF8EB797);
  static const pale = Color(0xFFDCE8D6);
  static const ink = Color(0xFF111111);
  static const brandInk = Color(0xFF203B46);
  static const blue = Color(0xFF103C71);
  static const secondary = Color(0xFF56616B);
  static const muted = Color(0xFF858F9B);
  static const border = Color(0xFFDEDFE2);
  static const disabled = Color(0xFFD0D0D0);
  static const toggleOff = Color(0xFFBCBDC0);
  static const back = Color(0xFFDEDEDB);
  static const sectionHeader = Color(0xFF0B3E33);

  // --- screen-specific ----------------------------------------------------
  static const splashBg = Color(0xFFEADCCF);
  static const photoFallback = Color(0xFFEAD8C8);
  static const ayahGreen = Color(0xFF00513E);
  static const collectionTitle = Color(0xFF003E31);
  static const subtitleBlue = Color(0xFF526085);
  static const pillBlue = Color(0xFF1748A0);
  static const refBlue = Color(0xFF0A2E75);
  static const homeBlue = Color(0xFF0A4594);
  static const searchGray = Color(0xFF687392);
  static const arabicInk = Color(0xFF0C0C0C);
  static const arabicBase = Color(0xFF101010);
  static const pageBg = Color(0xFFE9E9E9);

  // --- typography.css -----------------------------------------------------
  static const ui = 'Inter';
  static const display = 'DM Serif Display';
  static const arabic = 'Noto Naskh Arabic';
  static const urdu = 'Noto Nastaliq Urdu';
  static const bengali = 'Noto Sans Bengali';

  /// Reference artboard the HTML screens were designed against.
  static const designWidth = 393.0;
  static const designHeight = 852.0;
}

/// Semantic palette resolved per appearance mode, injected as a
/// [ThemeExtension] so screens read colors that react to the
/// Light/Dark/System setting. [DwPalette.light] mirrors the approved
/// design values exactly; [DwPalette.dark] is the brand-derived dark
/// set (photo screens keep their photos in both modes).
class DwPalette extends ThemeExtension<DwPalette> {
  const DwPalette({
    required this.background,
    required this.panel,
    required this.circle,
    required this.circleBorder,
    required this.hairline,
    required this.ink,
    required this.sub,
    required this.muted,
    required this.title,
    required this.subtitle,
    required this.blue,
    required this.section,
    required this.accent,
    required this.sheet,
  });

  final Color background; // flat-screen page background
  final Color panel; // settings panels / cards
  final Color circle; // icon circles
  final Color circleBorder;
  final Color hairline; // dividers & panel borders
  final Color ink; // primary text & icons
  final Color sub; // secondary text
  final Color muted;
  final Color title; // serif display headings
  final Color subtitle; // subtitle copy (blue family)
  final Color blue; // links & values (homeBlue family)
  final Color section; // letter-spaced section headers
  final Color accent; // brand green (selected states, logo)
  final Color sheet; // bottom sheets & dialogs

  static const DwPalette light = DwPalette(
    background: Dw.white,
    panel: Dw.settingsPanel,
    circle: Dw.white,
    circleBorder: Color(0xFFE3E3E5),
    hairline: Dw.border,
    ink: Dw.ink,
    sub: Dw.secondary,
    muted: Dw.muted,
    title: Dw.collectionTitle,
    subtitle: Dw.subtitleBlue,
    blue: Dw.homeBlue,
    section: Dw.sectionHeader,
    accent: Dw.forest,
    sheet: Dw.white,
  );

  static const DwPalette dark = DwPalette(
    background: Color(0xFF0F1714),
    panel: Color(0xFF1B2620),
    circle: Color(0xFF232F28),
    circleBorder: Color(0xFF33433B),
    hairline: Color(0xFF2C3A32),
    ink: Color(0xFFE9F0EB),
    sub: Color(0xFFA3B7AB),
    muted: Color(0xFF7E948A),
    title: Color(0xFFDCEBE2),
    subtitle: Color(0xFF9FB3D6),
    blue: Color(0xFFA5C5F2),
    section: Color(0xFF9FC4B1),
    accent: Color(0xFF7FB89E),
    sheet: Color(0xFF1E2923),
  );

  @override
  DwPalette copyWith({
    Color? background,
    Color? panel,
    Color? circle,
    Color? circleBorder,
    Color? hairline,
    Color? ink,
    Color? sub,
    Color? muted,
    Color? title,
    Color? subtitle,
    Color? blue,
    Color? section,
    Color? accent,
    Color? sheet,
  }) => DwPalette(
    background: background ?? this.background,
    panel: panel ?? this.panel,
    circle: circle ?? this.circle,
    circleBorder: circleBorder ?? this.circleBorder,
    hairline: hairline ?? this.hairline,
    ink: ink ?? this.ink,
    sub: sub ?? this.sub,
    muted: muted ?? this.muted,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    blue: blue ?? this.blue,
    section: section ?? this.section,
    accent: accent ?? this.accent,
    sheet: sheet ?? this.sheet,
  );

  @override
  DwPalette lerp(covariant DwPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;

  @override
  bool operator ==(Object other) =>
      other is DwPalette &&
      other.background == background &&
      other.panel == panel &&
      other.circle == circle &&
      other.circleBorder == circleBorder &&
      other.hairline == hairline &&
      other.ink == ink &&
      other.sub == sub &&
      other.muted == muted &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.blue == blue &&
      other.section == section &&
      other.accent == accent &&
      other.sheet == sheet;

  @override
  int get hashCode => Object.hash(
    background,
    panel,
    circle,
    circleBorder,
    hairline,
    ink,
    sub,
    muted,
    title,
    subtitle,
    blue,
    section,
    accent,
    sheet,
  );
}

extension DwPaletteOf on BuildContext {
  /// The active semantic palette (light or dark) from the ambient theme.
  DwPalette get dw => Theme.of(this).extension<DwPalette>() ?? DwPalette.light;
}
