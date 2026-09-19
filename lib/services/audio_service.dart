import 'dart:async';

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
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  String? _loadedUrl;

  /// Emits true/false as recitation starts and stops — including when a
  /// track naturally finishes. Broadcast, so several listeners are fine.
  Stream<bool> get stateStream => _stateController.stream;

  /// True while recitation audio is actively playing.
  bool get isPlaying => _player?.playing ?? false;

  /// Plays the recitation at [url], resuming instantly when the same ayah
  /// is already buffered. Throws on network/decoder failure — callers
  /// should catch and fall back to a paused visual state.
  Future<void> play(String url) async {
    final player = _player ??= AudioPlayer();
    _stateSub ??= player.playerStateStream.listen((state) {
      _stateController.add(state.playing);
    });
    if (_loadedUrl != url) {
      await player.setUrl(url);
      _loadedUrl = url;
    }
    await player.play();
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
    await _stateController.close();
    await _player?.dispose();
  }
}