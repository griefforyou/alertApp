import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/services.dart';

const _builtinSounds = [
  {'title': '清脆提示', 'uri': 'builtin:chime'},
  {'title': '柔和钟声', 'uri': 'builtin:bell'},
  {'title': '轻音提醒', 'uri': 'builtin:gentle'},
  {'title': '公鸡叫', 'uri': 'builtin:gongji'},
  {'title': '警告', 'uri': 'builtin:jinggao'},
  {'title': '猫叫', 'uri': 'builtin:maojiao'},
  {'title': '门铃', 'uri': 'builtin:menling'},
  {'title': '闹钟', 'uri': 'builtin:naozhong'},
  {'title': '下课铃声', 'uri': 'builtin:xiake'},
  {'title': '正确提示', 'uri': 'builtin:zhengque'},
];

/// 旧版内置铃声（中文 base，如 builtin:公鸡叫.mp3）→ 新 ASCII base 的映射。
/// 仅用于迁移用户已保存的旧铃声配置，新的 builtin URI 均为 ASCII。
const legacyBuiltinSoundMap = {
  '公鸡叫': 'gongji',
  '警告': 'jinggao',
  '猫叫': 'maojiao',
  '门铃': 'menling',
  '闹钟': 'naozhong',
  '下课铃声': 'xiake',
  '正确提示': 'zhengque',
};

/// 将内置铃声 URI 归一化为新 ASCII 格式（如 builtin:公鸡叫.mp3 → builtin:gongji）。
String normalizeBuiltinUri(String uri) {
  if (!uri.startsWith('builtin:')) return uri;
  final raw = uri.substring(8);
  final dot = raw.lastIndexOf('.');
  final base = dot > 0 ? raw.substring(0, dot) : raw;
  return 'builtin:${legacyBuiltinSoundMap[base] ?? base}';
}

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
