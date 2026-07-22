import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  static final ForegroundService _instance = ForegroundService._();
  static ForegroundService get instance => _instance;
  ForegroundService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'timer_channel',
        channelName: '计时器',
        channelDescription: '学习计时器后台运行',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );

    _initialized = true;
  }

  Future<void> start() async {
    if (!_initialized) return;

    final running = await FlutterForegroundTask.isRunningService;
    if (running) return;

    await FlutterForegroundTask.startService(
      notificationTitle: '学习计时器',
      notificationText: '正在计时...',
    );
  }

  Future<void> stop() async {
    if (!_initialized) return;

    final running = await FlutterForegroundTask.isRunningService;
    if (!running) return;

    await FlutterForegroundTask.stopService();
  }
}
