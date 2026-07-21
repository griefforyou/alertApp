import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationIO {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: '\u5b66\u4e60\u8ba1\u65f6\u5668',
      appUserModelId: 'StudyTimer.StudyTimer',
      guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      windows: windowsSettings,
    );

    try {
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
          await androidPlugin.requestNotificationsPermission();
        } catch (e) {
          debugPrint('Failed to request notification permission: $e');
        }
      }
    }
  }

  Future<void> show({required String title, required String body, String? soundUri}) async {
    if (!_initialized) return;
    try {
      final androidDetails = _buildAndroidDetails(soundUri);
      final iosDetails = _buildIosDetails(soundUri);
      final windowsDetails = _buildWindowsDetails(soundUri);
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails, windows: windowsDetails);
      final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  String _channelIdFor(String? soundUri) {
    if (soundUri == null || soundUri == 'default') return 'study_timer_default';
    return 'study_timer_${soundUri.hashCode}';
  }

  AndroidNotificationDetails _buildAndroidDetails(String? soundUri) {
    final channelId = _channelIdFor(soundUri);

    if (soundUri == null || soundUri == 'default') {
      return AndroidNotificationDetails(
        channelId, '\u5b66\u4e60\u8ba1\u65f6\u5668',
        channelDescription: '\u5b66\u4e60\u8ba1\u65f6\u5668\u63d0\u9192\u901a\u77e5',
        importance: Importance.high, priority: Priority.high,
      );
    }

    if (soundUri.startsWith('content://')) {
      return AndroidNotificationDetails(
        channelId, '\u5b66\u4e60\u8ba1\u65f6\u5668',
        channelDescription: '\u5b66\u4e60\u8ba1\u65f6\u5668\u63d0\u9192\u901a\u77e5',
        importance: Importance.high, priority: Priority.high,
        sound: UriAndroidNotificationSound(soundUri),
      );
    }

    if (soundUri.startsWith('builtin:')) {
      // Android release \u6784\u5efa\u4e0d\u4f1a\u628a res/raw \u7684 wav \u6253\u5305\u8fdb apk\uff0c
      // RawResourceAndroidNotificationSound \u627e\u4e0d\u5230\u8d44\u6e90\u4f1a\u65e0\u58f0\u3002
      // \u6539\u4e3a\u901a\u77e5\u9759\u97f3\uff0c\u7531\u5e94\u7528\u5c42\u7528 SoundService \u64ad\u653e assets \u91cc\u7684 wav\u3002
      return AndroidNotificationDetails(
        channelId, '\u5b66\u4e60\u8ba1\u65f6\u5668',
        channelDescription: '\u5b66\u4e60\u8ba1\u65f6\u5668\u63d0\u9192\u901a\u77e5',
        importance: Importance.high, priority: Priority.high,
        playSound: false,
      );
    }

    return AndroidNotificationDetails(
      channelId, '\u5b66\u4e60\u8ba1\u65f6\u5668',
      channelDescription: '\u5b66\u4e60\u8ba1\u65f6\u5668\u63d0\u9192\u901a\u77e5',
      importance: Importance.high, priority: Priority.high,
    );
  }

  DarwinNotificationDetails _buildIosDetails(String? soundUri) {
    if (soundUri == null || soundUri == 'default') {
      return const DarwinNotificationDetails();
    }
    if (soundUri.startsWith('builtin:')) {
      final name = '${soundUri.substring(8)}.wav';
      return DarwinNotificationDetails(sound: name);
    }
    return const DarwinNotificationDetails();
  }

  WindowsNotificationDetails _buildWindowsDetails(String? soundUri) {
    // Windows 无法可靠播放自定义音频作为通知音（仅 MSIX 打包才支持 asset）。
    // 选内置铃声时让 toast 静音，改由应用层用 SoundService 播放，避免双重声音。
    if (Platform.isWindows && soundUri != null && soundUri.startsWith('builtin:')) {
      return WindowsNotificationDetails(audio: WindowsNotificationAudio.silent());
    }
    return const WindowsNotificationDetails();
  }

  void cancelAll() {
    if (!_initialized) return;
    try {
      _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }
}
