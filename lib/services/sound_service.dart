import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  AudioPlayer? _player;
  static bool _configured = false;

  // 惰性创建：构造时不触碰插件通道，首次播放时才初始化 AudioPlayer。
  // 避免在无音频插件（如单元/组件测试环境）中构造即抛 MissingPluginException。
  AudioPlayer get _p {
    final p = _player ??= AudioPlayer();
    _configure();
    return p;
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
      final player = _p;
      // iOS Safari 要求媒体元素首次 play 必须在用户手势内，
      // 用 stop 模式复用以避免每次新建元素被 autoplay 拦截。
      await player.setReleaseMode(ReleaseMode.stop);
      await player.stop();
      final path = name.contains('.') ? name : '$name.wav';
      await player.play(AssetSource('sounds/$path'));
    } catch (e) {
      debugPrint('SoundService.playBuiltin($name) error: $e');
    }
  }

  Future<void> playBeep() => playBuiltin('gentle');

  /// 在用户手势内静默预热音频元素（iOS Safari autoplay 限制的解锁手段）。
  /// 音量归零播放后立即停止，元素保留复用；之后的定时触发放声无需手势即可播放。
  Future<void> warmUp(String name) async {
    final player = _p;
    final savedVolume = player.volume;
    try {
      await player.setVolume(0);
      await playBuiltin(name);
      await player.stop();
    } catch (e) {
      debugPrint('SoundService.warmUp($name) error: $e');
    } finally {
      await player.setVolume(savedVolume);
    }
  }

  void dispose() {
    _p.dispose();
  }
}
