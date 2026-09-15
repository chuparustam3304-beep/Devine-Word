import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'dw_svg.dart';

/// Floating circular play/pause control — the approved player's centre
/// button, freed from the card so it can be toggled from anywhere on the
/// home screen.
///
/// - Starts parked just above the "Swipe up for another ayah" strip,
///   aligned to the shared 25px left card inset.
/// - Drag to move it anywhere; clamped so it always stays fully on the
///   393x852 design frame.
/// - Tap toggles play/pause (recitation itself stays behind the future
///   AudioService; the control is visual for now).
class DraggablePlayButton extends StatefulWidget {
  const DraggablePlayButton({super.key, required this.initialPosition});

  /// Top-left corner in 393x852 design space.
  final Offset initialPosition;

  @override
  State<DraggablePlayButton> createState() => _DraggablePlayButtonState();
}

class _DraggablePlayButtonState extends State<DraggablePlayButton> {
  static const double _diameter = 60;
  static const double _edgeMargin = 8;

  late Offset _position = widget.initialPosition;

  /// Starts in the approved "playing" state (pause bars), matching the
  /// reference frame.
  bool _playing = true;

  Offset _clamped(Offset raw) {
    final maxDx = Dw.designWidth - _diameter - _edgeMargin;
    final maxDy = Dw.designHeight - _diameter - _edgeMargin;
    return Offset(
      raw.dx.clamp(_edgeMargin, maxDx).toDouble(),
      raw.dy.clamp(_edgeMargin, maxDy).toDouble(),
    );
  }

  void _onDrag(DragUpdateDetails details) {
    setState(() => _position = _clamped(_position + details.delta));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _playing = !_playing),
        onPanUpdate: _onDrag,
        child: Semantics(
          button: true,
          label: _playing ? 'Pause' : 'Play',
          child: Container(
            width: _diameter,
            height: _diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Dw.navSelected,
              border: Border.all(color: Dw.white.withValues(alpha: 0.75)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: DwSvg(
              _playing
                  ? 'assets/05-home/pause.svg'
                  : 'assets/05-home/play.svg',
              // 1.3x the approved 27px card icon.
              width: 35,
              height: 35,
              color: Dw.white,
            ),
          ),
        ),
      ),
    );
  }
}