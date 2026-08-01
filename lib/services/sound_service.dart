import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  final _player = AudioPlayer();
  static bool _configured = false;

  SoundService() {
    _configure();
    // 复用同一个 HTMLAudioElement：iOS Safari 要求媒体元素首次 play 必须在用户手势内。
    // 默认 ReleaseMode.release 会在停止/播完后销毁元素，导致定时触发的播放
    // 新建元素被 autoplay 拦截而无声（试听有声、通知无声）。
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
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
      final path = name.contains('.') ? name : '$name.wav';
      await _player.play(AssetSource('sounds/$path'));
    } catch (e) {
      debugPrint('SoundService.playBuiltin($name) error: $e');
    }
  }

  Future<void> playBeep() => playBuiltin('gentle');

  /// 在用户手势内静默预热音频元素（iOS Safari autoplay 限制的解锁手段）。
  /// 音量归零播放后立即停止，元素保留复用；之后的定时触发放声无需手势即可播放。
  Future<void> warmUp(String name) async {
    final savedVolume = _player.volume;
    try {
      await _player.setVolume(0);
      await playBuiltin(name);
      await _player.stop();
    } catch (e) {
      debugPrint('SoundService.warmUp($name) error: $e');
    } finally {
      await _player.setVolume(savedVolume);
    }
  }

  void dispose() {
    _player.dispose();
  }
}
