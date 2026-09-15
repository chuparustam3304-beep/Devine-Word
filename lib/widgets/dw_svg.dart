import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders an SVG asset shipped with the design pack.
class DwSvg extends StatelessWidget {
  const DwSvg(this.asset, {super.key, this.width, this.height, this.color});

  final String asset;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      fit: BoxFit.contain,
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
