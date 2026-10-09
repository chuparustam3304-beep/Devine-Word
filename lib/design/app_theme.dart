import 'package:flutter/material.dart';

import 'tokens.dart';

/// Application theme built from the design-system tokens. The approved
/// design ships a single light appearance.
ThemeData buildDevineWordTheme() => ThemeData(
  fontFamily: Dw.ui,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Dw.forest,
  ).copyWith(primary: Dw.forest, secondary: Dw.sage, surface: Dw.white),
  scaffoldBackgroundColor: Dw.pageBg,
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  textTheme: ThemeData(fontFamily: Dw.ui).textTheme.apply(
    bodyColor: Dw.ink,
    displayColor: Dw.ink,
  ),
);
