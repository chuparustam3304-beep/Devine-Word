import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders an SVG asset shipped with the design pack.
class DwSvg extends StatelessWidget {
  const DwSvg(this.asset, {super.key, this.width, this.height});

  final String asset;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

/// Renders an illustration asset at its own aspect ratio inside its box
/// (object-fit: contain).
///
/// The onboarding artwork ships as rasters rather than as [DwSvg]: a large
/// traced SVG has to be compiled into the `vector_graphics` format before it
/// can paint, and in a debug build that compile runs on the UI isolate — the
/// candle art alone cost ~1.3s there. A PNG is decoded by the engine off the
/// UI thread and paints on the next frame.
class DwContainImage extends StatelessWidget {
  const DwContainImage(this.asset, {super.key, this.fallbackColor});

  final String asset;

  /// Painted if the asset cannot be decoded; [Color] defaults to fully
  /// transparent, which leaves the screen's own canvas showing.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          ColoredBox(color: fallbackColor ?? const Color(0x00000000)),
    );
  }
}

/// Renders a full-bleed background photo asset (object-fit: cover).
class DwCoverImage extends StatelessWidget {
  const DwCoverImage(this.asset, {super.key, this.fallbackColor});

  final String asset;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            ColoredBox(color: fallbackColor ?? const Color(0xFFEAD8C8)),
      ),
    );
  }
}
