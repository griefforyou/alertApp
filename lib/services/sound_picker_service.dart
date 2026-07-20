import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundPickerService {
  static const _channel = MethodChannel('com.studytimer/sound_picker');

  Future<List<Map<String, String>>> getNotificationSounds() async {
    if (!Platform.isAndroid) return [];
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
}
