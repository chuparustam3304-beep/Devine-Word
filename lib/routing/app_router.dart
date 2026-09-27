/// Canonical route names for the finalized screens.
abstract final class Routes {
  static const splash = '/';
  // Onboarding runs in this order (each step replaces the previous one, so
  // Back never re-opens an earlier step unless that screen offers it):
  //   1. grow    — "Grow closer to GOD…"
  //   2. journey — "Every journey of faith is unique"
  //   3. quranic — "Everyday a new Quranic Ayah…" (Back returns to journey)
  static const onboardingGrow = '/onboarding/grow';
  static const onboardingJourney = '/onboarding/journey';
  static const onboardingQuranic = '/onboarding/quranic';
  static const home = '/home';
}
