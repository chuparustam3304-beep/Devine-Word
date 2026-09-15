import 'package:flutter/material.dart';

/// Paints an asset image composited onto its backdrop with a canvas-level
/// `BlendMode`, applying `fit` exactly like `Image`.
///
/// `Image.colorBlendMode` cannot be used for this because it is applied as a
/// `ColorFilter` on the image itself (and is ignored entirely when `color` is
/// null), so blends such as [BlendMode.darken] would never reach the widgets
/// painted underneath. Painting through `paintImage(blendMode: ...)` composites
/// against the real backdrop, which is what the approved artwork requires:
/// the illustration's opaque white surround must resolve onto the tinted base
/// layer painted beneath it, while deeper artwork keeps its own color.
class DwBlendImage extends StatefulWidget {
  const DwBlendImage({
    super.key,
    required this.asset,
    this.fit = BoxFit.cover,
    this.blendMode = BlendMode.srcOver,
  });

  final String asset;
  final BoxFit fit;
  final BlendMode blendMode;

  @override
  State<DwBlendImage> createState() => _DwBlendImageState();
}

class _DwBlendImageState extends State<DwBlendImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _imageInfo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant DwBlendImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _resolve();
    }
  }

  void _resolve() {
    final ImageStream newStream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    if (newStream.key == _stream?.key) {
      return;
    }
    _listener = _listener ?? ImageStreamListener(_onImage);
    _stream?.removeListener(_listener!);
    _stream = newStream;
    _stream!.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final ImageInfo? old = _imageInfo;
    _imageInfo = info;
    old?.dispose();
    if (!synchronousCall && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _imageInfo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlendImagePainter(
        imageInfo: _imageInfo,
        fit: widget.fit,
        blendMode: widget.blendMode,
      ),
    );
  }
}

class _BlendImagePainter extends CustomPainter {
  _BlendImagePainter({
    required this.imageInfo,
    required this.fit,
    required this.blendMode,
  });

  final ImageInfo? imageInfo;
  final BoxFit fit;
  final BlendMode blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    final ImageInfo? info = imageInfo;
    if (info == null) {
      return;
    }
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: info.image,
      scale: info.scale,
      fit: fit,
      blendMode: blendMode,
    );
  }

  @override
  bool shouldRepaint(_BlendImagePainter oldDelegate) {
    return oldDelegate.imageInfo != imageInfo ||
        oldDelegate.fit != fit ||
        oldDelegate.blendMode != blendMode;
  }
}
