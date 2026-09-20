import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint; // TEMP-DEBUG
import 'package:just_audio/just_audio.dart';

/// App-wide recitation playback behind the home screen's floating
/// play/pause control.
///
/// The platform player is created lazily on the first play request so that
/// widget tests — which swap [instance] for a fake — never touch the audio
/// stack, and so no resources are held before the user asks to listen.
class AudioService {
  AudioService();

  /// Single instance shared by every screen; tests may replace this with a
  /// fake before pumping widgets.
  static AudioService instance = AudioService();

  final _stateController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  int _rawTicks = 0; // TEMP-DEBUG
  String _pstate = ''; // TEMP-DEBUG

  /// TEMP-DEBUG: raw position ticks seen from the player.
  int get debugTicks => _rawTicks;

  /// TEMP-DEBUG: last processing state name.
  String get debugPstate => _pstate;
  String? _loadedUrl;

  /// Emits true/false as recitation starts and stops — including when a
  /// track naturally finishes. Broadcast, so several listeners are fine.
  Stream<bool> get stateStream => _stateController.stream;

  /// True while recitation audio is actively playing.
  bool get isPlaying => _player?.playing ?? false;

  /// Recitation position ticks (roughly every 200 ms) — consumed by the
  /// synced text highlighter. Broadcast; several listeners are fine.
  Stream<Duration> get positionStream => _positionController.stream;

  /// The recitation URL currently buffered, or null when nothing is loaded.
  String? get loadedUrl => _loadedUrl;

  /// Loads [url] (buffering as needed) and starts playback. Resolves once
  /// the source is loaded and playback has been requested — the actual
  /// playing/finished states arrive through [stateStream], so callers must
  /// not hold UI state (e.g. a spinner) on this future's completion.
  /// Re-loads are skipped when the same ayah is already buffered. Throws
  /// on network/decoder failure — callers should catch and fall back to a
  /// paused visual state.
  Future<void> play(String url) async {
    final player = _player ??= AudioPlayer();
    _stateSub ??= player.playerStateStream.listen((state) {
      // TEMP-DEBUG
      _pstate = state.processingState.name;
      _stateController.add(state.playing);
    });
    // TEMP-DEBUG (throttled: a per-tick print drowns the log)
    _positionSub ??= player.positionStream.listen((position) {
      _rawTicks++;
      _positionController.add(position);
    });
    if (_loadedUrl != url) {
      // TEMP-DEBUG
      debugPrint('DW-PLAY loading $url');
      try {
        final duration = await player.setUrl(url);
        // TEMP-DEBUG
        debugPrint('DW-PLAY loaded duration=$duration');
      } catch (error) {
        // TEMP-DEBUG
        debugPrint('DW-PLAY FAILED $error');
        rethrow;
      }
      _loadedUrl = url;
    }
    // After a completed track, start over; otherwise continue from the
    // paused position. The request is deliberately not awaited until the
    // end of playback — that state is what [stateStream] reports.
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    unawaited(player.play().catchError((_) {}));
  }

  /// True when a recitation for [url] is already loaded and merely paused,
  /// so [resume] continues it from the paused position without re-buffering.
  bool canResume(String url) {
    final player = _player;
    return player != null && _loadedUrl == url && !player.playing;
  }

  /// Resumes the loaded recitation from its current position — or restarts
  /// it from the beginning when it had finished. Returns false when there
  /// is nothing loaded to resume; callers fall back to [play].
  Future<bool> resume() async {
    final player = _player;
    if (player == null || _loadedUrl == null) return false;
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    unawaited(player.play().catchError((_) {}));
    return true;
  }

  /// Pauses playback, keeping the ayah buffered for an instant resume.
  Future<void> pause() async {
    await _player?.pause();
  }

  /// Stops playback and unloads the track — used when the home feed swipes
  /// to a different ayah.
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    await player.stop();
    _loadedUrl = null;
    _stateController.add(false);
  }

  /// Releases the audio resources. Not part of the normal app lifecycle.
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    await _stateController.close();
    await _positionController.close();
    await _player?.dispose();
  }
}