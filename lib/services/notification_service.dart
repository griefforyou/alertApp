import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/session_state.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  Future<void> schedulePhaseNotifications(SessionState session) async {
    if (!_initialized) return;
    await cancelAll();

    int totalSeconds = 0;
    int cycle = session.currentCycle;
    Phase phase = session.currentPhase;

    while (true) {
      if (cycle > session.totalCycles && session.totalCycles > 0) break;
      if (session.totalCycles == 0 && cycle > 100) break;

      if (phase == Phase.learning) {
        totalSeconds += session.studyMinutes * 60;
        await _scheduleNotification(
          id: cycle * 2 - 1,
          title: '学习结束',
          body: '第 $cycle 轮学习完成！休息 ${session.breakMinutes} 分钟',
          secondsFromNow: totalSeconds,
        );
        phase = Phase.breaking;
      } else {
        totalSeconds += session.breakMinutes * 60;
        await _scheduleNotification(
          id: cycle * 2,
          title: '休息结束',
          body: '休息时间到！开始第 ${cycle + 1} 轮学习',
          secondsFromNow: totalSeconds,
        );
        phase = Phase.learning;
        cycle++;
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int secondsFromNow,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'study_timer_channel',
      '学习计时器',
      channelDescription: '学习计时器提醒通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    final scheduledDate = tz.TZDateTime.from(
      DateTime.now().add(Duration(seconds: secondsFromNow)),
      tz.local,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
