# Devine Word

**A New Verse Everyday.**

Devine Word is a Quran reading and listening application built with Flutter.
It rebuilds the approved quranic-onboarding prototype and the botanical
reader home artboard pixel-faithfully at their design sizes (440 × 956 and
603 × 1280 design px).

## Screens

1. **Splash** — brand mark and loading indicator; routes to onboarding on the
   first launch and straight to home on every later launch.
2. **Onboarding Grow** — step 1, "Grow closer to GOD a little more everyday".
3. **Onboarding Journey** — step 2, "Every journey of faith is unique".
4. **Onboarding Quran** — step 3, the ayah rows; Continue completes
   onboarding and opens home.
5. **Home** — daily ayah deck with synchronized recitation highlighting,
   translation switch (Urdu/English/Bengali), reading-size stepper,
   Previous/Next deck controls, system share and the AdMob banner strip
   pinned below the artboard.

## Architecture

```
lib/
  main.dart                 App entry point and route table
  data/                     Models, QuranRepository (offline design set),
                            ApiQuranRepository (live daily pool),
                            RecitationTimingService (word timings)
  design/                   Design tokens, app theme, artboard screen frame
  routing/                  Canonical route names
  screens/                  One file per screen
  services/                 PreferencesService, AudioService, AdService
  state/                    AppState controller + inherited scope
  widgets/                  Reused approved components (onboarding controls,
                            nav controls, synced ayah text, ad banner)
```

State is a single `AppState extends ChangeNotifier` exposed through
`AppStateScope`. The onboarding flag persists through `PreferencesService`.
All Quran text flows through `QuranRepository`: the live pool fetched from
`api.alquran.cloud` at launch, with the approved design ayat as the offline
fallback.

## Recitation

Audio streams from the islamic.network CDN (Mishary Alafasy) and word-level
timings are read from quran.com's segment data, so the home card can
highlight the word currently being recited.

## Ads

Home pins a standard anchored-adaptive AdMob banner to the bottom of the
available screen width on Android and iOS. The ad stays below the player
controls and respects the system safe area. Its test creative may be narrower
than the responsive banner slot. If an ad cannot load, the reader remains
usable.

* Android App ID: `ca-app-pub-1873608409349621~6515568692`, configured in
  `android/app/src/main/AndroidManifest.xml`.
* iOS App ID: `ca-app-pub-1873608409349621~7130646369`, configured as
  `GADApplicationIdentifier` in `ios/Runner/Info.plist`.
* Debug builds use Google's platform-specific test banner units. Release
  builds use Android `ca-app-pub-1873608409349621/3932628220` and iOS
  `ca-app-pub-1873608409349621/9348606434`. See `AdService`.
* At startup, the app requests consent information and shows Google's UMP form
  when required. Ads are requested only when UMP reports `canRequestAds`; the
  privacy-options entry point appears when Google requires one.
* Ads are disabled under `flutter test`, where plugin platform channels do not
  exist. Before release, publish the consent message in AdMob and complete the
  store privacy/data disclosures for AdMob and the app's Quran/audio services.

## Launcher icons

The green-and-white brand icon source is `assets/launcher/app-icon.svg`; the
generated 1024px store image and Android adaptive foreground are in the same
directory. Regenerate Android and iOS icon sets after changing them with:

```sh
dart run flutter_launcher_icons
```

## Release builds

Android release signing must use a private upload keystore. Copy
`android/key.properties.example` to `android/key.properties`, fill it with the
keystore credentials, and place the keystore at the configured path. These
files are ignored by Git. Release builds intentionally fail until signing is
configured; debug signing is never used for a release.

Create the upload keystore locally (keep its password and backup private):

```sh
keytool -genkeypair -v -keystore android/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
```

```sh
flutter build appbundle --release
flutter build ios --release --no-codesign
```

Android currently targets API 36. The first command produces the Play upload
bundle after signing is configured.
The second checks the iOS release build but does not create a signed App Store
archive. Set the Apple Developer team and signing/provisioning in Xcode before
archiving for TestFlight or App Store Connect.

## Verified Quran text — content dependency

The design handoff requires that final Quran text comes from a **verified
Quran dataset**, never from the approved screen previews. The offline set
holds only the ayat the approved screens display verbatim; the live API pool
supplies the rest. For release, point `ApiQuranRepository` at the chosen
verified dataset (e.g. Tanzil verified Uthmani text with licensed
translations) — the interface is data-only, so no UI changes are needed.

## Development

```sh
flutter pub get
flutter analyze   # clean
flutter test      # unit + widget tests
flutter run
```

Dependencies are deliberately minimal: `flutter_svg` (design-pack SVG
assets), `shared_preferences` (persistence), `http` (Quran API),
`just_audio` (recitation), `share_plus` (system share sheet) and
`google_mobile_ads` (AdMob banner).
