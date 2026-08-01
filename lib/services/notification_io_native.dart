import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'sound_picker_service.dart';

class NotificationIO {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
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
  }

  Future<void> show({required String title, required String body, String? soundUri}) async {
    if (!_initialized) return;
    try {
      final androidDetails = _buildAndroidDetails(soundUri);
      // 前台由 SoundService 播放内置铃声，通知只出横幅（静音），避免双重声音。
      final iosDetails = _buildIosDetails(soundUri, presentSound: false);
      final windowsDetails = _buildWindowsDetails(soundUri);
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails, windows: windowsDetails);
      final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  static const int _scheduledNotifId = 999000001;

  Future<void> schedule({
    required String title,
    required String body,
    required DateTime date,
    String? soundUri,
  }) async {
    if (!_initialized) return;
    try {
      final androidDetails = _buildAndroidDetails(soundUri);
      final iosDetails = _buildIosDetails(soundUri);
      final windowsDetails = _buildWindowsDetails(soundUri);
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails, windows: windowsDetails);
      final tzDate = tz.TZDateTime.from(date, tz.local);
      await _plugin.zonedSchedule(
        id: _scheduledNotifId,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exact,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelScheduled() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _scheduledNotifId);
    } catch (e) {
      debugPrint('Failed to cancel scheduled notification: $e');
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

  DarwinNotificationDetails _buildIosDetails(String? soundUri, {bool presentSound = true}) {
    String? sound;
    if (soundUri != null && soundUri.startsWith('builtin:')) {
      // bundle 铃声统一用 ASCII 文件名 + .caf 容器：中文名在 Xcode 打包 /
      // UNNotificationSound soundNamed: 查找链路里不可靠，且实测 wav 在部分
      // iOS 上不播（回退系统默认音），caf 是 iOS 通知音最稳的格式。
      // legacyBuiltinSoundMap 兼容用户已保存的旧中文 URI。
      final raw = soundUri.substring(8);
      final dot = raw.lastIndexOf('.');
      final base = dot > 0 ? raw.substring(0, dot) : raw;
      sound = '${legacyBuiltinSoundMap[base] ?? base}.caf';
    }
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: presentSound,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.active,
      sound: sound,
    );
  }

  WindowsNotificationDetails _buildWindowsDetails(String? soundUri) {
    // Windows 无法可靠播放自定义音频作为通知音（仅 MSIX 打包才支持 asset）。
    // 选内置铃声时让 toast 静音，改由应用层用 SoundService 播放，避免双重声音。
    if (Platform.isWindows && soundUri != null && soundUri.startsWith('builtin:')) {
      return WindowsNotificationDetails(audio: WindowsNotificationAudio.silent());
    }
    return const WindowsNotificationDetails();
  }

  Future<void> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin == null) return;
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

  void cancelAll() {
    if (!_initialized) return;
    try {
      _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }
}
