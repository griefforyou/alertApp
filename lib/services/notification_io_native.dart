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
  }

  Future<void> show({required String title, required String body}) async {
    if (!_initialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'study_timer_channel',
        '\u5b66\u4e60\u8ba1\u65f6\u5668',
        channelDescription: '\u5b66\u4e60\u8ba1\u65f6\u5668\u63d0\u9192\u901a\u77e5',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const windowsDetails = WindowsNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails, windows: windowsDetails);
      final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
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
