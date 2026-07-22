import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  final _player = AudioPlayer();
  static bool _configured = false;

  SoundService() {
    _configure();
  }

  static void _configure() {
    if (_configured) return;
    _configured = true;
    unawaited(AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.duckOthers},
        ),
      ),
    ));
  }

  Future<void> playBuiltin(String name) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$name.wav'));
    } catch (e) {
      debugPrint('SoundService.playBuiltin($name) error: $e');
    }
  }

  Future<void> playBeep() => playBuiltin('gentle');

  void dispose() {
    _player.dispose();
  }
}
