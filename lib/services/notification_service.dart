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
  }

  Future<void> schedulePhaseNotifications(SessionState session, {String typeName = '学习'}) async {
    if (!_initialized) return;
    await cancelAll();

    final rounds = session.rounds;
    final hasMultiRound = rounds.length > 1;

    int totalSeconds = 0;
    int roundIdx = session.roundIndex;
    int cycle = session.currentCycle;
    Phase phase = session.currentPhase;

    while (true) {
      if (!session.multiCycle && cycle > session.currentCycle) break;
      if (cycle > session.totalCycles && session.totalCycles > 0) break;
      if (session.totalCycles == 0 && cycle > 100) break;

      final round = rounds[roundIdx.clamp(0, rounds.length - 1)];

      if (phase == Phase.learning) {
        totalSeconds += round.workMinutes * 60;
        final group = hasMultiRound ? '第 ${roundIdx + 1} 组 · ' : '';
        await _scheduleNotification(
          id: cycle * 2 - 1,
          title: '$typeName结束',
          body: '${group}第 $cycle 轮$typeName完成！休息 ${round.breakMinutes} 分钟',
          secondsFromNow: totalSeconds,
        );
        phase = Phase.breaking;
      } else {
        totalSeconds += round.breakMinutes * 60;
        final nextRoundIdx = roundIdx + 1;
        int nextCycle = cycle;
        int nextRound = nextRoundIdx;
        if (nextRoundIdx >= rounds.length) {
          nextRound = 0;
          nextCycle = cycle + 1;
        }
        final group = hasMultiRound ? '第 ${nextRound + 1} 组 · ' : '';
        await _scheduleNotification(
          id: cycle * 2,
          title: '休息结束',
          body: '${group}休息时间到！开始第 $nextCycle 轮$typeName',
          secondsFromNow: totalSeconds,
        );
        phase = Phase.learning;
        roundIdx = nextRound;
        cycle = nextCycle;
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int secondsFromNow,
  }) async {
    try {
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
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }
}
