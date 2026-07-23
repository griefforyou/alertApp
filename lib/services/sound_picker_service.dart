import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/services.dart';

const _builtinSounds = [
  {'title': '清脆提示', 'uri': 'builtin:chime'},
  {'title': '柔和钟声', 'uri': 'builtin:bell'},
  {'title': '轻音提醒', 'uri': 'builtin:gentle'},
];

class SoundPickerService {
  static const _channel = MethodChannel('com.studytimer/sound_picker');

  bool get hasBuiltinSounds => true;
  List<Map<String, String>> get builtinSounds => _builtinSounds;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<Map<String, String>>> getSystemSounds() async {
    if (!_isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getNotificationSounds');
      if (result == null) return [];
      return result.map((e) {
        final map = e as Map<dynamic, dynamic>;
        return {
          'title': (map['title'] as String?) ?? '',
          'uri': (map['uri'] as String?) ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to get notification sounds: $e');
      return [];
    }
  }

  Future<void> playRingtone(String uri) async {
    if (!_isAndroid) return;
    if (uri.startsWith('builtin:')) return;
    try {
      await _channel.invokeMethod('playRingtone', {'uri': uri});
    } catch (e) {
      debugPrint('Failed to play ringtone: $e');
    }
  }

  Future<void> stopRingtone() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stopRingtone');
    } catch (_) {}
  }
}
