import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob wiring: SDK startup, platform-specific banner IDs, and runtime guards
/// that keep ads out of widget tests and unsupported platforms. Ad failures
/// are non-fatal; the reading experience never depends on an ad arriving.
abstract final class AdService {
  /// Google's official Android test banner unit.
  static const androidTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Google's official iOS test banner unit.
  static const iosTestBannerUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  /// Devine Word's production Android banner unit.
  static const androidProductionBannerUnitId =
      'ca-app-pub-1873608409349621/3932628220';

  /// Devine Word's production iOS banner unit.
  static const iosProductionBannerUnitId =
      'ca-app-pub-1873608409349621/9348606434';

  /// Use Google's test unit in debug builds, and the platform's live unit in
  /// release builds.
  static String get bannerUnitId {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (kDebugMode) {
      return isIos ? iosTestBannerUnitId : androidTestBannerUnitId;
    }
    return isIos ? iosProductionBannerUnitId : androidProductionBannerUnitId;
  }

  /// True while running under `flutter test`, where the plugin's platform
  /// channels do not exist and touching the SDK would fail the test.
  static bool get isUnitTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Whether ads may be used at all: Android or iOS, outside tests.
  static bool get isEnabled =>
      !kIsWeb &&
      !isUnitTest &&
      (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void>? _initialization;
  static bool _canRequestAds = false;
  static bool _privacyOptionsRequired = false;

  static bool get canRequestAds => _canRequestAds;
  static bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Brings the Mobile Ads SDK up once, as early as possible after launch so
  /// the first banner request is not delayed. Safe to call repeatedly and
  /// safe to await from anywhere; failures are logged in debug, never thrown.
  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    if (!isEnabled) return;
    // Consent is read first, but the two steps are deliberately independent:
    // a consent lookup that fails (offline, or no privacy form published for
    // the app ID in the AdMob console) must not keep the SDK from starting.
    // Whether an ad may be *requested* is a separate question, answered by
    // [canRequestAds] at request time.
    await _refreshConsent();
    try {
      await MobileAds.instance.initialize();
    } catch (error) {
      _log('Mobile Ads initialize failed: $error');
    }
  }

  /// Reads the consent state, showing the required form on a first launch.
  ///
  /// Never throws. On failure [canRequestAds] stays false, which suppresses the
  /// banner; the reading experience is never affected.
  static Future<void> _refreshConsent() async {
    try {
      final consentInformation = ConsentInformation.instance;
      final consentUpdate = Completer<void>();
      consentInformation.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        consentUpdate.complete,
        (error) => consentUpdate.completeError(error),
      );
      await consentUpdate.future;
      // Google's own flow: only fall back to a form when consent is actually
      // required, which is also what keeps this a no-op outside the regions
      // where consent applies.
      if (!await consentInformation.canRequestAds()) {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      }
      await _readConsentState(consentInformation);
    } catch (error) {
      _log('consent update failed: $error');
      _canRequestAds = false;
      _privacyOptionsRequired = false;
    }
  }

  static Future<void> _readConsentState(
    ConsentInformation consentInformation,
  ) async {
    _canRequestAds = await consentInformation.canRequestAds();
    _privacyOptionsRequired =
        await consentInformation.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  /// Opens Google's required privacy choices form and refreshes consent state.
  static Future<void> showPrivacyOptionsForm() async {
    if (!isEnabled) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
      final consentInformation = ConsentInformation.instance;
      await _readConsentState(consentInformation);
      if (_canRequestAds) await MobileAds.instance.initialize();
    } catch (error) {
      _log('privacy options form failed: $error');
    }
  }

  /// Ads must never break the reader, but a silent failure is exactly how a
  /// misconfigured consent flow hides — so failures show up in debug builds.
  static void _log(String message) {
    if (kDebugMode) debugPrint('AdService: $message');
  }
}
