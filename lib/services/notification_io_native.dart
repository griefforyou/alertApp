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
      appName: '学习计时器',
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
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        try {
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
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
        channelId, '学习计时器',
        channelDescription: '学习计时器提醒通知',
        importance: Importance.high, priority: Priority.high,
      );
    }

    if (soundUri.startsWith('content://')) {
      return AndroidNotificationDetails(
        channelId, '学习计时器',
        channelDescription: '学习计时器提醒通知',
        importance: Importance.high, priority: Priority.high,
        sound: UriAndroidNotificationSound(soundUri),
      );
    }

    if (soundUri.startsWith('builtin:')) {
      // Android release 构建不会把 res/raw 的 wav 打包进 apk，
      // RawResourceAndroidNotificationSound 找不到资源会无声。
      // 改为通知静音，由应用层用 SoundService 播放 assets 里的 wav。
      return AndroidNotificationDetails(
        channelId, '学习计时器',
        channelDescription: '学习计时器提醒通知',
        importance: Importance.high, priority: Priority.high,
        playSound: false,
      );
    }

    return AndroidNotificationDetails(
      channelId, '学习计时器',
      channelDescription: '学习计时器提醒通知',
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
