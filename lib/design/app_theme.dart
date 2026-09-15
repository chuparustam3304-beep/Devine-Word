import 'package:flutter/material.dart';

import 'tokens.dart';

/// Application theme built from the design-system tokens. The light
/// theme mirrors the approved design; the dark theme swaps in
/// [DwPalette.dark] and dark surfaces for sheets, dialogs and pickers.
ThemeData buildDevineWordTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? DwPalette.dark : DwPalette.light;
  return ThemeData(
    fontFamily: Dw.ui,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Dw.forest,
      brightness: brightness,
    ).copyWith(
      primary: palette.accent,
      secondary: isDark ? palette.accent : Dw.sage,
      surface: palette.background,
    ),
    scaffoldBackgroundColor: palette.background,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    extensions: [palette],
    textTheme: ThemeData(brightness: brightness, fontFamily: Dw.ui)
        .textTheme
        .apply(bodyColor: palette.ink, displayColor: palette.ink),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: palette.sheet),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: palette.sheet,
      dialHandColor: palette.accent,
    ),
    snackBarTheme: isDark
        ? SnackBarThemeData(
            backgroundColor: palette.panel,
            contentTextStyle: TextStyle(color: palette.ink),
            behavior: SnackBarBehavior.floating,
          )
        : null,
  );
}
