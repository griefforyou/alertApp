import 'dart:html' show Notification;
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
        Notification(title, body: body);
      } else if (Notification.permission != 'denied') {
        final permission = await Notification.requestPermission();
        if (permission == 'granted') {
          Notification(title, body: body);
        }
      }
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<void> requestPermission() async {} 

  void cancelAll() {}
}
