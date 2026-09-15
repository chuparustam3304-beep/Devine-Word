# Devine Word

**A New Verse Everyday.**

Devine Word is a Quran reading and listening application built with Flutter.
The visual source of truth is the approved HTML/CSS design pack in the
sibling `screens/` directory (eight finalized screens, target artboard
393 × 852 CSS px), which this application reproduces pixel-faithfully.

## Screens

1. **Splash** — brand mark and loading indicator; routes to onboarding or home.
2. **Onboarding Read** — step 1, reading.
3. **Onboarding Listen** — step 2, listening.
4. **Onboarding Translation** — step 3, translation language choice (persists).
5. **Home** — daily ayah with translation, like/save/share, playback card.
6. **Saved Ayahs** — live bookmark list with working search.
7. **Recent Activity** — persisted reading events grouped by day with search.
8. **Settings** — translation language, text size, listening toggles, about.

## Architecture

```
lib/
  main.dart                 App entry point and route table
  data/                     Models and QuranRepository (verified-text source)
  design/                   Design tokens, app theme, 393×852 screen frame
  routing/                  Canonical route names and bottom-navigation
  screens/                  One file per finalized screen
  services/                 PreferencesService (shared_preferences key-space)
  state/                    AppState controller + inherited scope
  widgets/                  Reused approved components (nav, cards, player…)
```

State is a single `AppState extends ChangeNotifier` exposed through
`AppStateScope`; every mutation persists immediately via
`PreferencesService`. All Quran text flows through `QuranRepository`.

## Verified Quran text — content dependency

The design handoff requires that final Quran text comes from a **verified
Quran dataset** and must not be extracted from the approved screen previews.
No such dataset was supplied with the design pack. The repository currently
serves only the three ayat the approved screens themselves display verbatim
(Ash-Sharh 94:6, Ar-Ra'd 13:28, Ta-Ha 20:114) with their approved on-screen
translations. **Before release, wire a complete verified dataset (e.g. the
Tanzil verified Uthmani text with licensed translations) into
`QuranRepository.loadDailyPool()`** — the interface is data-only, so that
swap requires no UI changes.

## Recitation audio — missing production source

The approved player controls are reproduced faithfully, but no verified
recitation audio source or URL was supplied with the design pack. Static
timestamps in the player card are the approved design values, not a
functional audio player. Recitation audio must be supplied (a licensed
recitation CDN or bundled verified files) and isolated behind an
`AudioService` before the player can function.

## Development

```sh
flutter pub get
flutter analyze   # clean
flutter test      # unit + widget tests
flutter run
```

Dependencies are deliberately minimal: `flutter_svg` (design-pack SVG
assets), `shared_preferences` (persistence) and `share_plus` (system share
sheet).
