import 'dart:html' show Notification;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class NotificationIO {
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> show({required String title, required String body, String? soundUri}) async {
    try {
      if (Notification.permission == 'granted') {
        _showNotification(title, body);
      } else if (Notification.permission != 'denied') {
        final permission = await Notification.requestPermission();
        if (permission == 'granted') {
          _showNotification(title, body);
        }
      }
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// 每次启动调用：检查桌面通知权限，未决定过（default）才弹浏览器授权请求。
  /// granted/denied 不重复打扰用户。
  Future<void> requestPermission() async {
    try {
      if (Notification.permission == 'default') {
        await Notification.requestPermission();
      }
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
    }
  }

  void _showNotification(String title, String body) {
    // 点击通知聚焦已存在的窗口/标签页，而不是让浏览器新开一个窗口。
    final notification = Notification(title, body: body);
    notification.onClick.listen((_) {
      js.context.callMethod('focus');
      notification.close();
    });
  }

  Future<void> schedule({required String title, required String body, required DateTime date, String? soundUri}) async {}

  Future<void> cancelScheduled() async {}

  void cancelAll() {}
}
