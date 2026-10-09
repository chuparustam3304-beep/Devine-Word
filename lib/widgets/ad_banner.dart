import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// A responsive banner pinned to the bottom of its parent's available width.
/// Loading is best-effort: the slot holds the banner's height while the request
/// is in flight and collapses to zero if loading fails. Unit selection and
/// test/platform guards live in [AdService].
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.backgroundColor});

  /// Paints the strip behind the ad, including the bottom safe-area inset, so
  /// the banner blends with the screen it is pinned to.
  final Color? backgroundColor;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  /// Height reserved for the banner; null while there is nothing to show.
  AdSize? _slot;

  /// The loaded banner, once the SDK has one to display.
  BannerAd? _ad;

  /// The request still in flight, so it can be released when the screen goes
  /// away before the ad arrives. Null once the ad loaded, failed or was
  /// disposed — which is what keeps every ad disposed exactly once.
  BannerAd? _pending;

  /// Set on the first dependency change so the request is never repeated.
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _request();
  }

  @override
  void dispose() {
    _ad?.dispose();
    _pending?.dispose();
    _pending = null;
    super.dispose();
  }

  /// Reserves the banner strip, requests the ad, and gives the strip back
  /// again if anything goes wrong.
  Future<void> _request() async {
    if (!AdService.isEnabled) return;
    final media = MediaQuery.of(context);
    final slot = await _bannerSize(media);
    if (!mounted || slot == null) return;

    final ad = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: slot,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          _pending = null;
          if (!mounted) {
            loaded.dispose();
            return;
          }
          setState(() => _ad = loaded as BannerAd);
        },
        onAdFailedToLoad: (failedAd, error) {
          _pending = null;
          failedAd.dispose();
          if (!mounted) return;
          setState(() => _slot = null);
        },
      ),
    );
    _pending = ad;
    setState(() => _slot = slot);
    try {
      await ad.load();
    } catch (_) {
      // Already released by the listener or by `dispose` — never twice.
      if (_pending != null) ad.dispose();
      _pending = null;
      if (mounted) setState(() => _slot = null);
    }
  }

  /// The full-width anchored adaptive banner size for this screen, or null
  /// when the SDK cannot resolve one (nothing is shown then).
  Future<AdSize?> _bannerSize(MediaQueryData media) async {
    try {
      // Adaptive sizes can only be resolved once the SDK is up.
      await AdService.initialize();
      if (!AdService.canRequestAds) return null;
      // The large anchored size can be 100 points tall and cover the player
      // controls. Standard anchored adaptive keeps the width responsive with
      // a shorter bottom-banner height.
      // ignore: deprecated_member_use
      return await AdSize.getAnchoredAdaptiveBannerAdSize(
        media.orientation,
        media.size.width.truncate(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    if (slot == null) return const SizedBox.shrink();
    final ad = _ad;
    final strip = SafeArea(
      top: false,
      child: SizedBox(
        height: slot.height.toDouble(),
        width: double.infinity,
        child: ad == null ? null : Center(child: AdWidget(ad: ad)),
      ),
    );
    final background = widget.backgroundColor;
    return background == null
        ? strip
        : ColoredBox(color: background, child: strip);
  }
}
