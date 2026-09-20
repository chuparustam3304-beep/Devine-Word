import 'dart:async';

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../services/audio_service.dart';
import 'dw_svg.dart';

/// Floating circular play/pause control — the approved player's centre
/// button, freed from the card so it can be toggled from anywhere on the
/// home screen.
///
/// - Starts parked just above the "Swipe up for another ayah" strip,
///   aligned to the shared 25px left card inset.
/// - Drag to move it anywhere; clamped so it always stays fully on the
///   393x852 design frame.
/// - Tap plays/pauses the on-screen ayah's recitation through
///   [AudioService]; swiping to another ayah stops playback and resets
///   the control. Taps always give visible feedback — a buffering spinner
///   while the stream loads, and a message if it can't start.
class DraggablePlayButton extends StatefulWidget {
  const DraggablePlayButton({
    super.key,
    required this.initialPosition,
    this.audioUrl,
  });

  /// Top-left corner in 393x852 design space.
  final Offset initialPosition;

  /// Recitation stream of the ayah currently on screen; null when none.
  final String? audioUrl;

  @override
  State<DraggablePlayButton> createState() => _DraggablePlayButtonState();
}

class _DraggablePlayButtonState extends State<DraggablePlayButton> {
  static const double _diameter = 60;
  static const double _edgeMargin = 8;

  late Offset _position = widget.initialPosition;

  /// The icon mirrors real playback: paused (play triangle) until the user
  /// taps, playing (pause bars) while recitation is audible, paused again
  /// when a track finishes naturally.
  bool _playing = false;

  /// True while the recitation stream buffers — the circle shows a spinner
  /// so a tap always gives visible feedback.
  bool _busy = false;
  StreamSubscription<bool>? _playbackSub;

  @override
  void initState() {
    super.initState();
    // Returning to home with audio still running must not show a stale
    // paused icon.
    _playing = AudioService.instance.isPlaying;
    _playbackSub = AudioService.instance.stateStream.listen((playing) {
      if (!mounted) return;
      if (_playing == playing) return;
      setState(() => _playing = playing);
    });
    // TEMP-DEBUG: auto-start playback so a headless run can be observed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTap());
  }

  @override
  void didUpdateWidget(covariant DraggablePlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.audioUrl != oldWidget.audioUrl) {
      // A different ayah swiped in — drop the old recitation.
      _playing = false;
      unawaited(AudioService.instance.stop());
    }
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    super.dispose();
  }

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

  Future<void> _onTap() async {
    if (_busy) {
      // The first buffer is still loading — nothing to pause yet; the
      // spinner communicates the state.
      return;
    }
    final url = widget.audioUrl;
    if (url == null) {
      _announce('No recitation available for this ayah.');
      return;
    }
    if (_playing) {
      // Pause at any point during playback — the position is kept so the
      // next tap resumes exactly from here.
      setState(() => _playing = false);
      unawaited(AudioService.instance.pause());
      return;
    }
    // Buffering state gives the tap immediate visible feedback.
    setState(() => _busy = true);
    try {
      // Already buffered and paused? Resume from the same position
      // without re-downloading; otherwise load and play.
      final resumed = await AudioService.instance.resume();
      if (!resumed) {
        await AudioService.instance.play(url);
      }
    } catch (_) {
      // Stream unreachable / decoder error / platform plugin missing.
      if (mounted) {
        setState(() => _playing = false);
        _announce("Couldn't load the recitation — check your connection.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Surfaces feedback through the nearest Scaffold instead of leaving the
  /// control silently inert.
  void _announce(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
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
            child: _busy
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Dw.white,
                    ),
                  )
                : DwSvg(
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