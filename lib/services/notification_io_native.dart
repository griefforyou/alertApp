import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationIO {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _lastChannelId;

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
      const windowsDetails = WindowsNotificationDetails();
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
      final name = soundUri.substring(8);
      return AndroidNotificationDetails(
        channelId, '\u5b66\u4e60\u8ba1\u65f6\u5668',
        channelDescription: '\u5b66\u4e60\u8ba1\u65f6\u5668\u63d0\u9192\u901a\u77e5',
        importance: Importance.high, priority: Priority.high,
        sound: RawResourceAndroidNotificationSound(name),
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

  void cancelAll() {
    if (!_initialized) return;
    try {
      _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }
}
